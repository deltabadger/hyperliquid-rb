# frozen_string_literal: true

require "json"
require "securerandom"

module Hyperliquid
  class Exchange
    DEFAULT_SLIPPAGE = 0.05

    attr_reader :info, :signer
    attr_accessor :expires_after

    # @param private_key [String] hex private key
    # @param base_url [String] API URL (defaults to mainnet)
    # @param vault_address [String, nil] default vault address for all operations
    # @param account_address [String, nil] address to use for queries (e.g. when trading as agent)
    def initialize(private_key:, base_url: MAINNET_URL, vault_address: nil, account_address: nil, skip_ws: false)
      @signer = Signer.new(private_key: private_key, base_url: base_url)
      @info = Info.new(base_url: base_url, skip_ws: skip_ws)
      @transport = Transport.new(base_url: base_url)
      @vault_address = vault_address
      @account_address = account_address
      @expires_after = nil
    end

    def address
      @signer.address
    end

    # Set expiration for subsequent actions (millisecond timestamp).
    # Not supported on user-signed actions.
    # @param expires_after [Integer, nil] timestamp in ms, or nil to clear
    def set_expires_after(expires_after)
      @expires_after = expires_after
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
        asset = @info.name_to_asset(req[:coin])
        Utils.order_request_to_order_wire(req, asset)
      end

      action = { "type" => "order", "orders" => wires, "grouping" => grouping }
      action["builder"] = { "b" => builder["b"].downcase, "f" => builder["f"] } if builder

      vault = vault_address || @vault_address
      post_action(action, vault_address: vault)
    end

    # Market open: buy/sell at market with slippage tolerance.
    # @param coin [String]
    # @param is_buy [Boolean]
    # @param sz [Float] size
    # @param px [Float, nil] reference price (default: mid price)
    # @param slippage [Float] slippage as decimal (default 0.05 = 5%)
    # @param cloid [Cloid, nil]
    # @param builder [Hash, nil]
    def market_open(coin, is_buy:, sz:, px: nil, slippage: DEFAULT_SLIPPAGE, cloid: nil, builder: nil)
      px = slippage_price(coin, is_buy, slippage, px)
      order(coin, is_buy: is_buy, sz: sz, limit_px: px,
                  order_type: { limit: { "tif" => "Ioc" } }, cloid: cloid, builder: builder)
    end

    # Market close: close entire position (or partial) at market.
    # @param coin [String]
    # @param sz [Float, nil] size to close (default: entire position)
    # @param px [Float, nil] reference price (default: mid price)
    # @param slippage [Float]
    # @param cloid [Cloid, nil]
    # @param builder [Hash, nil]
    def market_close(coin, sz: nil, px: nil, slippage: DEFAULT_SLIPPAGE, cloid: nil, builder: nil)
      addr = @account_address || @vault_address || address
      state = @info.user_state(addr)
      position = state["assetPositions"]&.find { |p| p["position"]["coin"] == coin }
      raise Error, "No open position for #{coin}" unless position

      szi = position["position"]["szi"].to_f
      is_buy = szi < 0 # close short = buy, close long = sell
      sz ||= szi.abs

      px = slippage_price(coin, is_buy, slippage, px)
      order(coin, is_buy: is_buy, sz: sz, limit_px: px,
                  order_type: { limit: { "tif" => "Ioc" } }, reduce_only: true, cloid: cloid, builder: builder)
    end

    # ---- Modify Orders ----

    # Modify a single order.
    # @param oid [Integer, Cloid] order ID or client order ID to modify
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
        asset = @info.name_to_asset(mod[:order][:coin])
        oid_val = mod[:oid].is_a?(Cloid) ? mod[:oid].to_raw : mod[:oid]
        {
          "oid" => oid_val,
          "order" => Utils.order_request_to_order_wire(mod[:order], asset)
        }
      end

      action = { "type" => "batchModify", "modifies" => wires }
      post_action(action)
    end

    # ---- Cancel Orders ----

    # Cancel a single order by order ID.
    # @param coin [String]
    # @param oid [Integer]
    def cancel(coin, oid)
      bulk_cancel([{ coin: coin, oid: oid }])
    end

    # Cancel a single order by client order ID.
    # @param coin [String]
    # @param cloid [Cloid]
    def cancel_by_cloid(coin, cloid)
      bulk_cancel_by_cloid([{ coin: coin, cloid: cloid }])
    end

    # Cancel multiple orders by order ID.
    # @param cancels [Array<Hash>] each with :coin and :oid keys
    def bulk_cancel(cancels)
      cancel_wires = cancels.map do |c|
        asset = @info.name_to_asset(c[:coin])
        { "a" => asset, "o" => c[:oid] }
      end

      action = { "type" => "cancel", "cancels" => cancel_wires }
      post_action(action)
    end

    # Cancel multiple orders by client order ID.
    # @param cancels [Array<Hash>] each with :coin and :cloid keys
    def bulk_cancel_by_cloid(cancels)
      cancel_wires = cancels.map do |c|
        asset = @info.name_to_asset(c[:coin])
        { "asset" => asset, "cloid" => c[:cloid].to_s }
      end

      action = { "type" => "cancelByCloid", "cancels" => cancel_wires }
      post_action(action)
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
      asset = @info.name_to_asset(coin)
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
      asset = @info.name_to_asset(coin)
      action = { "type" => "twapCancel", "a" => asset, "t" => twap_id }
      post_action(action)
    end

    # ---- Account ----

    # Update leverage for a coin.
    # @param coin [String]
    # @param leverage [Integer]
    # @param is_cross [Boolean]
    def update_leverage(coin, leverage:, is_cross: true)
      asset = @info.name_to_asset(coin)
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
      asset = @info.name_to_asset(coin)
      action = {
        "type" => "updateIsolatedMargin",
        "asset" => asset,
        "isBuy" => is_buy,
        "ntli" => Utils.float_to_usd_int(amount)
      }
      post_action(action)
    end

    # Set referrer code.
    # @param code [String] referral code
    def set_referrer(code)
      action = { "type" => "setReferrer", "code" => code }
      post_action(action, vault_address: nil)
    end

    # ---- Transfers (user-signed actions) ----

    # Transfer USD to another address.
    # @param destination [String] recipient address
    # @param amount [Float] USD amount
    def usd_transfer(destination, amount:)
      action = {
        "type" => "usdSend",
        "destination" => destination,
        "amount" => amount.to_s,
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
        "amount" => amount.to_s,
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
        "amount" => amount.to_s,
        "time" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "Withdraw")
    end

    # Transfer between perp and spot.
    # @param amount [Float] USD amount
    # @param to_perp [Boolean] true = spot->perp, false = perp->spot
    def usd_class_transfer(amount:, to_perp:)
      ts = timestamp_ms
      str_amount = amount.to_s
      str_amount += " subaccount:#{@vault_address}" if @vault_address

      action = {
        "type" => "usdClassTransfer",
        "amount" => str_amount,
        "toPerp" => to_perp,
        "nonce" => ts
      }
      post_user_signed_action(action, primary_type: "UsdClassTransfer")
    end

    # Send asset between dexes.
    # @param destination [String] recipient address
    # @param source_dex [String] source dex identifier
    # @param destination_dex [String] destination dex identifier
    # @param token [String] token identifier
    # @param amount [Float] amount to send
    def send_asset(destination, source_dex:, destination_dex:, token:, amount:)
      ts = timestamp_ms
      action = {
        "type" => "sendAsset",
        "destination" => destination,
        "sourceDex" => source_dex,
        "destinationDex" => destination_dex,
        "token" => token,
        "amount" => amount.to_s,
        "fromSubAccount" => @vault_address || "",
        "nonce" => ts
      }
      post_user_signed_action(action, primary_type: "SendAsset")
    end

    # ---- Agent / Builder ----

    # Approve an agent to trade on your behalf.
    # Generates a new agent key and returns [response, agent_private_key].
    # @param name [String, nil] agent name
    # @return [Array] [response, agent_private_key_hex]
    def approve_agent(name: nil)
      agent_key = "0x#{SecureRandom.hex(32)}"
      agent_account = Eth::Key.new(priv: agent_key.delete_prefix("0x"))
      ts = timestamp_ms

      action = {
        "type" => "approveAgent",
        "agentAddress" => agent_account.address.to_s,
        "agentName" => name || "",
        "nonce" => ts
      }
      sig = @signer.sign_user_signed_action(
        action,
        primary_type: "ApproveAgent",
        payload_types: USER_SIGNED_TYPES["ApproveAgent"]
      )

      # Remove agentName from action if no name provided (matches Python SDK behavior)
      action.delete("agentName") if name.nil?

      payload = { action: action, nonce: ts, signature: sig }
      result = @transport.post_exchange(payload)

      [result, agent_key]
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
      post_action(action, vault_address: nil)
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
      post_action(action, vault_address: nil)
    end

    # Transfer spot tokens to/from a sub-account.
    # @param sub_account_user [String]
    # @param is_deposit [Boolean]
    # @param token [String]
    # @param amount [Float]
    def sub_account_spot_transfer(sub_account_user:, is_deposit:, token:, amount:)
      action = {
        "type" => "subAccountSpotTransfer",
        "subAccountUser" => sub_account_user,
        "isDeposit" => is_deposit,
        "token" => token,
        "amount" => amount.to_s
      }
      post_action(action, vault_address: nil)
    end

    # ---- Vault ----

    # Transfer USD to/from a vault.
    # @param vault_address [String] vault address
    # @param is_deposit [Boolean]
    # @param usd [Integer] amount
    def vault_usd_transfer(vault_address:, is_deposit:, usd:)
      action = {
        "type" => "vaultTransfer",
        "vaultAddress" => vault_address,
        "isDeposit" => is_deposit,
        "usd" => usd
      }
      post_action(action, vault_address: nil)
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

    # ---- Multi-sig ----

    # Convert account to multi-sig.
    # @param authorized_users [Array<String>] list of authorized signer addresses
    # @param threshold [Integer] number of signatures required
    def convert_to_multi_sig_user(authorized_users:, threshold:)
      sorted_users = authorized_users.sort
      signers = { "authorizedUsers" => sorted_users, "threshold" => threshold }
      action = {
        "type" => "convertToMultiSigUser",
        "signers" => JSON.generate(signers),
        "nonce" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "ConvertToMultiSigUser")
    end

    # Execute a multi-sig action.
    # @param multi_sig_user [String] multi-sig user address
    # @param inner_action [Hash] the action to execute
    # @param signatures [Array] existing signatures
    # @param nonce [Integer] nonce
    # @param vault_address [String, nil]
    def multi_sig(multi_sig_user, inner_action, signatures, nonce, vault_address: nil)
      multi_sig_action = {
        "type" => "multiSig",
        "signatureChainId" => "0x66eee",
        "signatures" => signatures,
        "payload" => {
          "multiSigUser" => multi_sig_user.downcase,
          "outerSigner" => @signer.address.downcase,
          "action" => inner_action
        }
      }

      sig = @signer.sign_multi_sig_action(multi_sig_action, vault_address: vault_address, nonce: nonce,
                                                            expires_after: @expires_after)

      payload = {
        action: multi_sig_action,
        nonce: nonce,
        signature: sig,
        vaultAddress: vault_address,
        expiresAfter: @expires_after
      }
      @transport.post_exchange(payload)
    end

    # ---- Spot Deploy ----

    # Register a new spot token.
    def spot_deploy_register_token(token_name:, sz_decimals:, wei_decimals:, max_gas:, full_name:)
      action = {
        "type" => "spotDeploy",
        "registerToken2" => {
          "spec" => { "name" => token_name, "szDecimals" => sz_decimals, "weiDecimals" => wei_decimals },
          "maxGas" => max_gas,
          "fullName" => full_name
        }
      }
      post_action(action, vault_address: nil)
    end

    # User genesis for a spot token.
    def spot_deploy_user_genesis(token:, user_and_wei:, existing_token_and_wei:)
      action = {
        "type" => "spotDeploy",
        "userGenesis" => {
          "token" => token,
          "userAndWei" => user_and_wei.map { |user, wei| [user.downcase, wei] },
          "existingTokenAndWei" => existing_token_and_wei
        }
      }
      post_action(action, vault_address: nil)
    end

    # Enable freeze privilege for a spot token.
    def spot_deploy_enable_freeze_privilege(token)
      spot_deploy_token_action("enableFreezePrivilege", token)
    end

    # Freeze/unfreeze a user for a spot token.
    def spot_deploy_freeze_user(token, user:, freeze:)
      action = {
        "type" => "spotDeploy",
        "freezeUser" => { "token" => token, "user" => user.downcase, "freeze" => freeze }
      }
      post_action(action, vault_address: nil)
    end

    # Revoke freeze privilege for a spot token.
    def spot_deploy_revoke_freeze_privilege(token)
      spot_deploy_token_action("revokeFreezePrivilege", token)
    end

    # Enable quote token for a spot token.
    def spot_deploy_enable_quote_token(token)
      spot_deploy_token_action("enableQuoteToken", token)
    end

    # Run genesis for a spot token.
    def spot_deploy_genesis(token, max_supply:, no_hyperliquidity: false)
      genesis = { "token" => token, "maxSupply" => max_supply }
      genesis["noHyperliquidity"] = true if no_hyperliquidity
      action = { "type" => "spotDeploy", "genesis" => genesis }
      post_action(action, vault_address: nil)
    end

    # Register a spot trading pair.
    def spot_deploy_register_spot(base_token:, quote_token:)
      action = {
        "type" => "spotDeploy",
        "registerSpot" => { "tokens" => [base_token, quote_token] }
      }
      post_action(action, vault_address: nil)
    end

    # Register hyperliquidity for a spot pair.
    def spot_deploy_register_hyperliquidity(spot, start_px:, order_sz:, n_orders:, n_seeded_levels: nil)
      register = {
        "spot" => spot,
        "startPx" => start_px.to_s,
        "orderSz" => order_sz.to_s,
        "nOrders" => n_orders
      }
      register["nSeededLevels"] = n_seeded_levels if n_seeded_levels
      action = { "type" => "spotDeploy", "registerHyperliquidity" => register }
      post_action(action, vault_address: nil)
    end

    # Set deployer trading fee share for a spot token.
    def spot_deploy_set_deployer_trading_fee_share(token, share:)
      action = {
        "type" => "spotDeploy",
        "setDeployerTradingFeeShare" => { "token" => token, "share" => share }
      }
      post_action(action, vault_address: nil)
    end

    # ---- Perp Deploy ----

    # Register a new perp asset.
    def perp_deploy_register_asset(dex:, coin:, sz_decimals:, oracle_px:, margin_table_id:,
                                   only_isolated:, max_gas: nil, schema: nil)
      schema_wire = nil
      if schema
        schema_wire = {
          "fullName" => schema[:full_name],
          "collateralToken" => schema[:collateral_token],
          "oracleUpdater" => schema[:oracle_updater]&.downcase
        }
      end
      action = {
        "type" => "perpDeploy",
        "registerAsset" => {
          "maxGas" => max_gas,
          "assetRequest" => {
            "coin" => coin,
            "szDecimals" => sz_decimals,
            "oraclePx" => oracle_px,
            "marginTableId" => margin_table_id,
            "onlyIsolated" => only_isolated
          },
          "dex" => dex,
          "schema" => schema_wire
        }
      }
      post_action(action, vault_address: nil)
    end

    # Set oracle prices for a perp dex.
    def perp_deploy_set_oracle(dex:, oracle_pxs:, all_mark_pxs:, external_perp_pxs:)
      action = {
        "type" => "perpDeploy",
        "setOracle" => {
          "dex" => dex,
          "oraclePxs" => oracle_pxs.sort.to_a,
          "markPxs" => all_mark_pxs.map { |m| m.sort.to_a },
          "externalPerpPxs" => external_perp_pxs.sort.to_a
        }
      }
      post_action(action, vault_address: nil)
    end

    # ---- C-Signer ----

    # Unjail self as c-signer.
    def c_signer_unjail_self
      c_signer_action("unjailSelf")
    end

    # Jail self as c-signer.
    def c_signer_jail_self
      c_signer_action("jailSelf")
    end

    # ---- C-Validator ----

    # Register as a validator.
    def c_validator_register(node_ip:, name:, description:, delegations_disabled:, commission_bps:,
                             signer:, unjailed:, initial_wei:)
      action = {
        "type" => "CValidatorAction",
        "register" => {
          "profile" => {
            "node_ip" => { "Ip" => node_ip },
            "name" => name,
            "description" => description,
            "delegations_disabled" => delegations_disabled,
            "commission_bps" => commission_bps,
            "signer" => signer
          },
          "unjailed" => unjailed,
          "initial_wei" => initial_wei
        }
      }
      post_action(action, vault_address: nil)
    end

    # Change validator profile.
    def c_validator_change_profile(unjailed:, node_ip: nil, name: nil, description: nil,
                                   disable_delegations: nil, commission_bps: nil, signer: nil)
      action = {
        "type" => "CValidatorAction",
        "changeProfile" => {
          "node_ip" => node_ip ? { "Ip" => node_ip } : nil,
          "name" => name,
          "description" => description,
          "unjailed" => unjailed,
          "disable_delegations" => disable_delegations,
          "commission_bps" => commission_bps,
          "signer" => signer
        }
      }
      post_action(action, vault_address: nil)
    end

    # Unregister as a validator.
    def c_validator_unregister
      action = { "type" => "CValidatorAction", "unregister" => nil }
      post_action(action, vault_address: nil)
    end

    # ---- EVM / Blocks ----

    # Enable or disable big blocks.
    # @param enable [Boolean]
    def use_big_blocks(enable)
      action = { "type" => "evmUserModify", "usingBigBlocks" => enable }
      post_action(action, vault_address: nil)
    end

    # ---- Dex Abstraction ----

    # Enable dex abstraction for an agent.
    def agent_enable_dex_abstraction
      action = { "type" => "agentEnableDexAbstraction" }
      post_action(action)
    end

    # Set abstraction level for an agent.
    # @param abstraction [String] "u", "p", or "i"
    def agent_set_abstraction(abstraction)
      action = { "type" => "agentSetAbstraction", "abstraction" => abstraction }
      post_action(action)
    end

    # Set dex abstraction for a user (user-signed action).
    # @param user [String] user address
    # @param enabled [Boolean]
    def user_dex_abstraction(user, enabled:)
      action = {
        "type" => "userDexAbstraction",
        "user" => user.downcase,
        "enabled" => enabled,
        "nonce" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "UserDexAbstraction")
    end

    # Set user abstraction level (user-signed action).
    # @param user [String] user address
    # @param abstraction [String] "unifiedAccount", "portfolioMargin", or "disabled"
    def user_set_abstraction(user, abstraction:)
      action = {
        "type" => "userSetAbstraction",
        "user" => user.downcase,
        "abstraction" => abstraction,
        "nonce" => timestamp_ms
      }
      post_user_signed_action(action, primary_type: "UserSetAbstraction")
    end

    # ---- Noop ----

    # Send a no-op action (useful for testing signing).
    # @param nonce [Integer]
    def noop(nonce)
      action = { "type" => "noop" }
      post_action(action, nonce: nonce)
    end

    private

    def post_action(action, vault_address: :default, nonce: nil)
      vault = vault_address == :default ? @vault_address : vault_address
      # usdClassTransfer and sendAsset don't include vaultAddress
      vault = nil if %w[usdClassTransfer sendAsset].include?(action["type"])

      nonce ||= timestamp_ms
      sig = @signer.sign_l1_action(action, nonce: nonce, vault_address: vault, expires_after: @expires_after)

      payload = { action: action, nonce: nonce, signature: sig }
      payload[:vaultAddress] = vault if vault
      payload[:expiresAfter] = @expires_after if @expires_after

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

    def slippage_price(coin, is_buy, slippage, px = nil)
      unless px
        full_coin = @info.name_to_coin(coin)
        dex = full_coin.include?(":") ? full_coin.split(":")[0] : ""
        mids = @info.all_mids(dex: dex)
        mid = mids[full_coin]
        raise Error, "No mid price for #{coin}" unless mid

        px = mid.to_f
      end

      asset = @info.name_to_asset(coin)
      is_spot = asset >= 10_000

      px = if is_buy
             px * (1 + slippage)
           else
             [px * (1 - slippage), 0].max
           end

      # Round to 5 significant figures, with appropriate decimal places
      sz_decimals = @info.asset_to_sz_decimals(asset) || 0
      max_decimals = is_spot ? 8 : 6
      decimal_places = [max_decimals - sz_decimals, 0].max
      rounded = format("%.5g", px).to_f
      rounded.round(decimal_places)
    end

    def spot_deploy_token_action(variant, token)
      action = { "type" => "spotDeploy", variant => { "token" => token } }
      post_action(action, vault_address: nil)
    end

    def c_signer_action(variant)
      action = { "type" => "CSignerAction", variant => nil }
      post_action(action, vault_address: nil)
    end

    def timestamp_ms
      (Time.now.to_f * 1000).to_i
    end
  end
end
