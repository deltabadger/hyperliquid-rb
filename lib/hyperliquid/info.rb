# frozen_string_literal: true

module Hyperliquid
  class Info
    attr_reader :transport

    def initialize(base_url: MAINNET_URL, skip_ws: false)
      @transport = Transport.new(base_url: base_url)
      @coin_to_asset = nil
      @spot_coin_to_asset = nil
      @name_to_coin = nil
      @asset_to_sz_decimals = nil
      @ws_manager = nil
      return if skip_ws

      @ws_manager = WebsocketManager.new(base_url)
      @ws_manager.start
    end

    # ---- Market Data ----

    # Get perpetual metadata (universe, asset info).
    # @param dex [String, nil] optional dex identifier for builder perp dexs
    def meta(dex: nil)
      if dex && !dex.empty?
        post("meta", dex: dex)
      else
        post("meta")
      end
    end

    # Get spot metadata.
    def spot_meta
      post("spotMeta")
    end

    # Get perpetual metadata with live asset contexts (funding, open interest, etc).
    def meta_and_asset_ctxs
      post("metaAndAssetCtxs")
    end

    # Get spot metadata with live asset contexts.
    def spot_meta_and_asset_ctxs
      post("spotMetaAndAssetCtxs")
    end

    # Get all mid prices. Returns Hash of coin => mid price string.
    # @param dex [String, nil] optional dex identifier for builder perp dexs
    def all_mids(dex: nil)
      if dex && !dex.empty?
        post("allMids", dex: dex)
      else
        post("allMids")
      end
    end

    # Get L2 order book snapshot.
    # @param coin [String] e.g. "ETH"
    # @param n_levels [Integer] number of price levels (default: 10)
    def l2_snapshot(coin, n_levels: 10)
      post("l2Book", coin: coin, nSigFigs: n_levels)
    end

    # Get candle data.
    # @param coin [String] e.g. "ETH"
    # @param interval [String] e.g. "1h", "1d", "15m"
    # @param start_time [Integer] start timestamp in ms
    # @param end_time [Integer] end timestamp in ms
    def candles_snapshot(coin, interval:, start_time:, end_time:)
      post("candleSnapshot", req: { coin: coin, interval: interval, startTime: start_time, endTime: end_time })
    end

    # Get list of perp dexes.
    def perp_dexs
      post("perpDexs")
    end

    # ---- User State ----

    # Get user's perpetual account state (positions, margin, etc).
    # @param address [String] user address
    # @param dex [String, nil] optional dex identifier
    def user_state(address, dex: nil)
      if dex && !dex.empty?
        post("clearinghouseState", user: address, dex: dex)
      else
        post("clearinghouseState", user: address)
      end
    end

    # Get user's spot account state.
    # @param address [String] user address
    def spot_user_state(address)
      post("spotClearinghouseState", user: address)
    end

    # Get user's open orders.
    # @param address [String] user address
    # @param dex [String, nil] optional dex identifier
    def open_orders(address, dex: nil)
      if dex && !dex.empty?
        post("openOrders", user: address, dex: dex)
      else
        post("openOrders", user: address)
      end
    end

    # Get user's open orders with additional frontend info.
    # @param address [String] user address
    # @param dex [String, nil] optional dex identifier
    def frontend_open_orders(address, dex: nil)
      if dex && !dex.empty?
        post("frontendOpenOrders", user: address, dex: dex)
      else
        post("frontendOpenOrders", user: address)
      end
    end

    # Get user's trade fills.
    # @param address [String] user address
    def user_fills(address)
      post("userFills", user: address)
    end

    # Get user's trade fills in a time range.
    # @param address [String] user address
    # @param start_time [Integer] start timestamp in ms
    # @param end_time [Integer] end timestamp in ms (optional)
    # @param aggregate_by_time [Boolean] aggregate fills by time (optional)
    def user_fills_by_time(address, start_time:, end_time: nil, aggregate_by_time: nil)
      req = { user: address, startTime: start_time }
      req[:endTime] = end_time if end_time
      req[:aggregateByTime] = aggregate_by_time unless aggregate_by_time.nil?
      post("userFillsByTime", **req)
    end

    # Get user's fee rates.
    # @param address [String] user address
    def user_fees(address)
      post("userFees", user: address)
    end

    # Get user's funding history.
    # @param address [String] user address
    # @param start_time [Integer] start timestamp in ms
    # @param end_time [Integer] end timestamp in ms (optional)
    def user_funding(address, start_time:, end_time: nil)
      req = { user: address, startTime: start_time }
      req[:endTime] = end_time if end_time
      post("userFunding", **req)
    end

    # Get user's non-funding ledger updates.
    # @param address [String] user address
    # @param start_time [Integer] start timestamp in ms
    # @param end_time [Integer] end timestamp in ms (optional)
    def user_non_funding_ledger_updates(address, start_time:, end_time: nil)
      req = { user: address, startTime: start_time }
      req[:endTime] = end_time if end_time
      post("userNonFundingLedgerUpdates", **req)
    end

    # Get user's rate limits.
    # @param address [String] user address
    def user_rate_limit(address)
      post("userRateLimit", user: address)
    end

    # ---- Orders ----

    # Query status of an order by oid or cloid.
    # @param address [String] user address
    # @param oid [Integer, String] order id (Integer) or cloid (String)
    def order_status(address, oid)
      post("orderStatus", user: address, oid: oid)
    end

    # Get user's historical orders (up to 2000 recent).
    # @param address [String] user address
    def historical_orders(address)
      post("historicalOrders", user: address)
    end

    # ---- Funding ----

    # Get funding history for a coin.
    # @param coin [String] e.g. "ETH"
    # @param start_time [Integer] start timestamp in ms
    # @param end_time [Integer] end timestamp in ms (optional)
    def funding_history(coin, start_time:, end_time: nil)
      req = { coin: coin, startTime: start_time }
      req[:endTime] = end_time if end_time
      post("fundingHistory", **req)
    end

    # Get predicted funding rates.
    def predicted_fundings
      post("predictedFundings")
    end

    # ---- Sub-accounts ----

    # Get sub-accounts for an address.
    # @param address [String] user address
    def sub_accounts(address)
      post("subAccounts", user: address)
    end

    # ---- Staking ----

    # Get user's staking summary (delegated, undelegated, pending).
    # @param address [String] user address
    def user_staking_summary(address)
      post("delegatorSummary", user: address)
    end

    # Get user's staking delegations per validator.
    # @param address [String] user address
    def user_staking_delegations(address)
      post("delegations", user: address)
    end

    # Get user's historic staking rewards.
    # @param address [String] user address
    def user_staking_rewards(address)
      post("delegatorRewards", user: address)
    end

    # Get comprehensive delegator history.
    # @param address [String] user address
    def delegator_history(address)
      post("delegatorHistory", user: address)
    end

    # ---- Referrals ----

    # Get referral state for an address.
    # @param address [String] user address
    def referral(address)
      post("referral", user: address)
    end

    # ---- Multi-sig ----

    # Get multi-sig signers for a user.
    # @param address [String] multi-sig user address
    def query_user_to_multi_sig_signers(address)
      post("userToMultiSigSigners", user: address)
    end

    # ---- Deploy Auctions ----

    # Get perp deploy auction status.
    def query_perp_deploy_auction_status
      post("perpDeployAuctionStatus")
    end

    # Get spot deploy state for a user.
    # @param address [String] user address
    def query_spot_deploy_auction_status(address)
      post("spotDeployState", user: address)
    end

    # ---- Dex Abstraction ----

    # Get dex abstraction state for a user.
    # @param address [String] user address
    def query_user_dex_abstraction_state(address)
      post("userDexAbstraction", user: address)
    end

    # Get user abstraction state.
    # @param address [String] user address
    def query_user_abstraction_state(address)
      post("userAbstraction", user: address)
    end

    # ---- Portfolio / TWAP / Vault ----

    # Get portfolio performance data.
    # @param address [String] user address
    def portfolio(address)
      post("portfolio", user: address)
    end

    # Get user's TWAP slice fills.
    # @param address [String] user address
    def user_twap_slice_fills(address)
      post("userTwapSliceFills", user: address)
    end

    # Get user's vault equity positions.
    # @param address [String] user address
    def user_vault_equities(address)
      post("userVaultEquities", user: address)
    end

    # Get user's role and account type.
    # @param address [String] user address
    def user_role(address)
      post("userRole", user: address)
    end

    # Get extra agents for a user.
    # @param address [String] user address
    def extra_agents(address)
      post("extraAgents", user: address)
    end

    # ---- WebSocket ----

    # Subscribe to a WebSocket channel.
    # @param subscription [Hash] e.g. { "type" => "allMids" } or { "type" => "l2Book", "coin" => "ETH" }
    # @param callback [Proc] called with each message hash
    # @return [Integer] subscription_id for unsubscribing
    def subscribe(subscription, callback)
      remap_coin_subscription(subscription)
      raise "Cannot call subscribe since skip_ws was used" if @ws_manager.nil?

      @ws_manager.subscribe(subscription, callback)
    end

    # Unsubscribe from a WebSocket channel.
    # @param subscription [Hash] same hash used to subscribe
    # @param subscription_id [Integer] returned by subscribe
    # @return [Boolean] true if subscription was found and removed
    def unsubscribe(subscription, subscription_id)
      remap_coin_subscription(subscription)
      raise "Cannot call unsubscribe since skip_ws was used" if @ws_manager.nil?

      @ws_manager.unsubscribe(subscription, subscription_id)
    end

    # Disconnect the WebSocket connection and stop the ping thread.
    def disconnect_websocket
      raise "Cannot call disconnect_websocket since skip_ws was used" if @ws_manager.nil?

      @ws_manager.stop
    end

    # ---- Coin-to-asset mapping (lazy loaded) ----

    # Map a coin name to its asset index (handles both perp and spot).
    # This is the primary method used by Exchange for resolving coin names.
    # @param name [String] e.g. "ETH", "BTC", "PURR/USDC"
    # @return [Integer] asset index
    def name_to_asset(name)
      load_all_mappings! unless @name_to_coin
      coin = @name_to_coin[name]
      raise Error, "Unknown coin name: #{name}" unless coin

      asset = @coin_to_asset[coin]
      raise Error, "Unknown coin: #{coin}" unless asset

      asset
    end

    # Map a coin name to its perpetual asset index.
    # @param coin [String] e.g. "ETH"
    # @return [Integer] asset index
    def coin_to_asset(coin)
      load_coin_mapping! unless @coin_to_asset
      @coin_to_asset[coin] || raise(Error, "Unknown perpetual coin: #{coin}")
    end

    # Map a coin name to its spot asset index (10000 + index).
    # @param coin [String] e.g. "PURR/USDC"
    # @return [Integer] asset index
    def spot_coin_to_asset(coin)
      load_spot_coin_mapping! unless @spot_coin_to_asset
      @spot_coin_to_asset[coin] || raise(Error, "Unknown spot coin: #{coin}")
    end

    # Get sz decimals for an asset index.
    # @param asset [Integer] asset index
    # @return [Integer] sz decimals
    def asset_to_sz_decimals(asset)
      load_all_mappings! unless @asset_to_sz_decimals
      @asset_to_sz_decimals[asset]
    end

    # Get the full coin name (with dex prefix if applicable) for a display name.
    # @param name [String] e.g. "ETH"
    # @return [String] coin name
    def name_to_coin(name)
      load_all_mappings! unless @name_to_coin
      @name_to_coin[name] || raise(Error, "Unknown name: #{name}")
    end

    # Reset cached coin mappings (e.g. after new listings).
    def refresh_coin_mappings!
      @coin_to_asset = nil
      @spot_coin_to_asset = nil
      @name_to_coin = nil
      @asset_to_sz_decimals = nil
    end

    private

    def remap_coin_subscription(subscription)
      type = subscription["type"]
      return unless %w[l2Book trades candle bbo activeAssetCtx].include?(type)

      load_all_mappings! unless @name_to_coin
      coin = @name_to_coin[subscription["coin"]]
      subscription["coin"] = coin if coin
    end

    def post(type, **params)
      body = { type: type }.merge(params)
      @transport.post_info(body)
    end

    def load_coin_mapping!
      m = meta
      @coin_to_asset = {}
      m["universe"].each_with_index do |asset_info, index|
        @coin_to_asset[asset_info["name"]] = index
      end
    end

    def load_spot_coin_mapping!
      m = spot_meta
      @spot_coin_to_asset = {}
      m["universe"].each_with_index do |token_info, index|
        name = token_info["name"]
        @spot_coin_to_asset[name] = 10_000 + index
      end
    end

    def load_all_mappings!
      @coin_to_asset = {}
      @name_to_coin = {}
      @asset_to_sz_decimals = {}

      # Load perp metadata
      m = meta
      set_perp_meta(m, 0)

      # Load spot metadata
      begin
        sm = spot_meta
        sm["universe"].each_with_index do |token_info, index|
          name = token_info["name"]
          asset = 10_000 + index
          @coin_to_asset[name] = asset
          @name_to_coin[name] = name
        end
        sm["tokens"]&.each do |token|
          @asset_to_sz_decimals[token["index"]] = token["szDecimals"] if token["index"]
        end
      rescue Error
        # spot_meta may not be available
      end

      # Load builder perp dexes
      begin
        dexes = perp_dexs
        dexes&.each_with_index do |dex, i|
          offset = 110_000 + (i * 10_000)
          begin
            dex_meta = meta(dex: dex)
            set_perp_meta(dex_meta, offset, dex: dex)
          rescue Error
            # dex meta may not be available
          end
        end
      rescue Error
        # perp_dexs may not be available
      end

      @spot_coin_to_asset = @coin_to_asset.select { |_k, v| v >= 10_000 && v < 110_000 }
    end

    def set_perp_meta(m, offset, dex: nil)
      m["universe"].each_with_index do |asset_info, index|
        name = asset_info["name"]
        coin = dex && !dex.empty? ? "#{dex}:#{name}" : name
        asset = offset + index
        @coin_to_asset[coin] = asset
        @name_to_coin[name] = coin
        @asset_to_sz_decimals[asset] = asset_info["szDecimals"]
      end
    end
  end
end
