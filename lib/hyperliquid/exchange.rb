# frozen_string_literal: true

module Hyperliquid
  class Exchange
    attr_reader :info, :signer

    # @param private_key [String] hex private key
    # @param base_url [String] API URL (defaults to mainnet)
    # @param vault_address [String, nil] default vault address for all operations
    def initialize(private_key:, base_url: MAINNET_URL, vault_address: nil)
      @signer = Signer.new(private_key: private_key, base_url: base_url)
      @info = Info.new(base_url: base_url)
      @transport = Transport.new(base_url: base_url)
      @vault_address = vault_address
    end

    def address
      @signer.address
    end

    # ---- Orders ----

    # Place a single order.
    # @param coin [String] e.g. "ETH"
    # @param is_buy [Boolean]
    # @param sz [Float] order size
    # @param limit_px [Float] limit price
    # @param order_type [Hash] e.g. { limit: { "tif" => "Gtc" } } or { trigger: { ... } }
    # @param reduce_only [Boolean]
    # @param cloid [Cloid, nil] client order ID
    # @param builder [Hash, nil] e.g. { "b" => "0x...", "f" => 10 }
    # @param vault_address [String, nil] override default vault
    def order(coin, is_buy:, sz:, limit_px:, order_type:, reduce_only: false, cloid: nil, builder: nil,
              vault_address: nil)
      order_request = {
        coin: coin, is_buy: is_buy, sz: sz, limit_px: limit_px,
        order_type: order_type, reduce_only: reduce_only, cloid: cloid
      }
      bulk_orders([order_request], builder: builder, vault_address: vault_address)
    end

    # Place multiple orders at once.
    # @param order_requests [Array<Hash>] array of order request hashes
    # @param grouping [String] "na", "normalTpsl", or "positionTpsl"
    # @param builder [Hash, nil]
    # @param vault_address [String, nil]
    def bulk_orders(order_requests, grouping: "na", builder: nil, vault_address: nil)
      wires = order_requests.map do |req|
        asset = @info.coin_to_asset(req[:coin])
        Utils.order_request_to_order_wire(req, asset)
      end

      action = { "type" => "order", "orders" => wires, "grouping" => grouping }
      action["builder"] = builder if builder

      vault = vault_address || @vault_address
      post_action(action, vault_address: vault)
    end

    # Market open: buy/sell at market with slippage tolerance.
    # @param coin [String]
    # @param is_buy [Boolean]
    # @param sz [Float] size
    # @param slippage [Float] slippage as decimal (default 0.05 = 5%)
    # @param cloid [Cloid, nil]
    def market_open(coin, is_buy:, sz:, slippage: 0.05, cloid: nil)
      px = get_slippage_price(coin, is_buy, slippage)
      order(coin, is_buy: is_buy, sz: sz, limit_px: px,
                  order_type: { limit: { "tif" => "Ioc" } }, cloid: cloid)
    end

    # Market close: close entire position at market.
    # @param coin [String]
    # @param slippage [Float]
    # @param cloid [Cloid, nil]
    def market_close(coin, slippage: 0.05, cloid: nil)
      state = @info.user_state(address)
      position = state["assetPositions"]&.find { |p| p["position"]["coin"] == coin }
      raise Error, "No open position for #{coin}" unless position

      szi = position["position"]["szi"].to_f
      is_buy = szi < 0 # close short = buy, close long = sell
      sz = szi.abs

      px = get_slippage_price(coin, is_buy, slippage)
      order(coin, is_buy: is_buy, sz: sz, limit_px: px,
                  order_type: { limit: { "tif" => "Ioc" } }, reduce_only: true, cloid: cloid)
    end

    # ---- Modify Orders ----

    # Modify a single order.
    # @param oid [Integer] order ID to modify
    # @param coin [String]
    # @param is_buy [Boolean]
    # @param sz [Float]
    # @param limit_px [Float]
    # @param order_type [Hash]
    # @param reduce_only [Boolean]
    # @param cloid [Cloid, nil]
    def modify_order(oid, coin:, is_buy:, sz:, limit_px:, order_type:, reduce_only: false, cloid: nil)
      order_request = {
        coin: coin, is_buy: is_buy, sz: sz, limit_px: limit_px,
        order_type: order_type, reduce_only: reduce_only, cloid: cloid
      }
      bulk_modify_orders([{ oid: oid, order: order_request }])
    end

    # Modify multiple orders at once.
    # @param modifications [Array<Hash>] each with :oid and :order keys
    def bulk_modify_orders(modifications)
      wires = modifications.map do |mod|
        asset = @info.coin_to_asset(mod[:order][:coin])
        {
          "oid" => mod[:oid],
          "order" => Utils.order_request_to_order_wire(mod[:order], asset)
        }
      end

      action = { "type" => "batchModify", "modifies" => wires }
      post_action(action)
    end

    # ---- Cancel Orders ----

    # Cancel orders by order ID.
    # @param cancels [Array<Hash>] each with :coin and :oid keys
    def cancel(cancels)
      cancel_wires = cancels.map do |c|
        asset = @info.coin_to_asset(c[:coin])
        { "a" => asset, "o" => c[:oid] }
      end

      action = { "type" => "cancel", "cancels" => cancel_wires }
      post_action(action)
    end

    # Cancel orders by client order ID.
    # @param cancels [Array<Hash>] each with :coin and :cloid keys
    def cancel_by_cloid(cancels)
      cancel_wires = cancels.map do |c|
        asset = @info.coin_to_asset(c[:coin])
        { "asset" => asset, "cloid" => c[:cloid].to_s }
      end

      action = { "type" => "cancelByCloid", "cancels" => cancel_wires }
      post_action(action)
    end

    # Cancel all open orders (optionally filtered by coin).
    # @param coin [String, nil] cancel only this coin's orders, or all if nil
    def cancel_all(coin: nil)
      orders = @info.open_orders(address)
      orders = orders.select { |o| o["coin"] == coin } if coin
      return if orders.empty?

      cancels = orders.map { |o| { coin: o["coin"], oid: o["oid"] } }
      cancel(cancels)
    end

    # Schedule cancel-all after a delay.
    # @param time [Integer, nil] timestamp in ms when to cancel. nil to clear.
    def schedule_cancel(time: nil)
      action = { "type" => "scheduleCancel" }
      action["time"] = time if time
      post_action(action)
    end

    # ---- TWAP ----

    # Place a TWAP order.
    # @param coin [String]
    # @param is_buy [Boolean]
    # @param sz [Float]
    # @param reduce_only [Boolean]
    # @param minutes [Integer] duration
    # @param randomize [Boolean] randomize execution
    def twap_order(coin, is_buy:, sz:, minutes:, reduce_only: false, randomize: true)
      asset = @info.coin_to_asset(coin)
      action = {
        "type" => "twapOrder",
        "twap" => {
          "a" => asset,
          "b" => is_buy,
          "s" => Utils.float_to_wire(sz),
          "r" => reduce_only,
          "m" => minutes,
          "t" => randomize
        }
      }
      post_action(action)
    end

    # Cancel a TWAP order.
    # @param coin [String]
    # @param twap_id [Integer]
    def twap_cancel(coin, twap_id:)
      asset = @info.coin_to_asset(coin)
      action = { "type" => "twapCancel", "a" => asset, "t" => twap_id }
      post_action(action)
    end

    # ---- Account ----

    # Update leverage for a coin.
    # @param coin [String]
    # @param leverage [Integer]
    # @param is_cross [Boolean]
    def update_leverage(coin, leverage:, is_cross: true)
      asset = @info.coin_to_asset(coin)
      action = {
        "type" => "updateLeverage",
        "asset" => asset,
        "isCross" => is_cross,
        "leverage" => leverage
      }
      post_action(action)
    end

    # Update isolated margin for a coin.
    # @param coin [String]
    # @param is_buy [Boolean]
    # @param amount [Float] USD amount (positive = add, negative = remove)
    def update_isolated_margin(coin, is_buy:, amount:)
      asset = @info.coin_to_asset(coin)
      action = {
        "type" => "updateIsolatedMargin",
        "asset" => asset,
        "isBuy" => is_buy,
        "ntli" => Utils.float_to_usd_int(amount)
      }
      post_action(action)
    end

    # ---- Transfers (user-signed actions) ----

    # Transfer USD to another address.
    # @param destination [String] recipient address
    # @param amount [Float] USD amount
    def usd_transfer(destination, amount:)
      action = {
        "type" => "usdSend",
        "destination" => destination,
        "amount" => Utils.float_to_wire(amount),
        "time" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "UsdSend")
    end

    # Transfer spot tokens to another address.
    # @param destination [String] recipient address
    # @param token [String] token identifier
    # @param amount [Float]
    def spot_transfer(destination, token:, amount:)
      action = {
        "type" => "spotSend",
        "destination" => destination,
        "token" => token,
        "amount" => Utils.float_to_wire(amount),
        "time" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "SpotSend")
    end

    # Withdraw USDC from bridge to L1.
    # @param destination [String] recipient address
    # @param amount [Float] USDC amount
    def withdraw_from_bridge(destination, amount:)
      action = {
        "type" => "withdraw3",
        "destination" => destination,
        "amount" => Utils.float_to_wire(amount),
        "time" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "Withdraw")
    end

    # Transfer between perp and spot.
    # @param amount [Float] USD amount
    # @param to_perp [Boolean] true = spot->perp, false = perp->spot
    def usd_class_transfer(amount:, to_perp:)
      action = {
        "type" => "usdClassTransfer",
        "amount" => Utils.float_to_wire(amount),
        "toPerp" => to_perp,
        "nonce" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "UsdClassTransfer")
    end

    # ---- Agent / Builder ----

    # Approve an agent to trade on your behalf.
    # @param agent_address [String]
    # @param agent_name [String]
    def approve_agent(agent_address:, agent_name: "")
      action = {
        "type" => "approveAgent",
        "agentAddress" => agent_address,
        "agentName" => agent_name,
        "nonce" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "ApproveAgent")
    end

    # Approve a builder fee.
    # @param builder [String] builder address
    # @param max_fee_rate [String] max fee rate
    def approve_builder_fee(builder:, max_fee_rate:)
      action = {
        "type" => "approveBuilderFee",
        "maxFeeRate" => max_fee_rate,
        "builder" => builder,
        "nonce" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "ApproveBuilderFee")
    end

    # ---- Sub-accounts ----

    # Create a sub-account.
    # @param name [String] sub-account name
    def create_sub_account(name:)
      action = { "type" => "createSubAccount", "name" => name }
      post_action(action)
    end

    # Transfer USD to/from a sub-account.
    # @param sub_account_user [String] sub-account address
    # @param is_deposit [Boolean] true = deposit into sub, false = withdraw
    # @param usd [Integer] USD amount (raw integer)
    def sub_account_transfer(sub_account_user:, is_deposit:, usd:)
      action = {
        "type" => "subAccountTransfer",
        "subAccountUser" => sub_account_user,
        "isDeposit" => is_deposit,
        "usd" => usd
      }
      post_action(action)
    end

    # Transfer spot tokens to/from a sub-account.
    # @param sub_account_user [String]
    # @param is_deposit [Boolean]
    # @param token [String]
    # @param amount [String]
    def sub_account_spot_transfer(sub_account_user:, is_deposit:, token:, amount:)
      action = {
        "type" => "subAccountSpotTransfer",
        "subAccountUser" => sub_account_user,
        "isDeposit" => is_deposit,
        "token" => token,
        "amount" => amount
      }
      post_action(action)
    end

    # ---- Staking ----

    # Delegate or undelegate tokens.
    # @param validator [String] validator address
    # @param wei [Integer] amount in wei
    # @param is_undelegate [Boolean]
    def token_delegate(validator:, wei:, is_undelegate: false)
      action = {
        "type" => "tokenDelegate",
        "validator" => validator,
        "wei" => wei,
        "isUndelegate" => is_undelegate,
        "nonce" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "TokenDelegate")
    end

    private

    def post_action(action, vault_address: nil)
      vault = vault_address || @vault_address
      nonce = timestamp_ms
      sig = @signer.sign_l1_action(action, nonce: nonce, vault_address: vault)

      payload = { action: action, nonce: nonce, signature: sig }
      payload[:vaultAddress] = vault if vault

      @transport.post_exchange(payload)
    end

    def post_user_signed_action(action, primary_type:)
      payload_types = USER_SIGNED_TYPES[primary_type]
      raise Error, "Unknown user-signed action type: #{primary_type}" unless payload_types

      sig = @signer.sign_user_signed_action(
        action,
        primary_type: primary_type,
        payload_types: payload_types
      )

      payload = { action: action, nonce: timestamp_ms, signature: sig }
      @transport.post_exchange(payload)
    end

    def get_slippage_price(coin, is_buy, slippage)
      mids = @info.all_mids
      mid = mids[coin]
      raise Error, "No mid price for #{coin}" unless mid

      mid_px = mid.to_f
      if is_buy
        px = mid_px * (1 + slippage)
      else
        px = mid_px * (1 - slippage)
        px = [px, 0].max
      end

      # Round to 5 significant figures (standard for HL)
      round_to_sig_figs(px, 5)
    end

    def round_to_sig_figs(value, sig_figs)
      return 0.0 if value == 0

      d = (Math.log10(value.abs).floor + 1).to_i
      factor = 10.0**(sig_figs - d)
      (value * factor).round / factor
    end

    def timestamp_ms
      (Time.now.to_f * 1000).to_i
    end
  end
end
