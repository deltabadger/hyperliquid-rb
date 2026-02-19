# frozen_string_literal: true

module Hyperliquid
  class Info
    attr_reader :transport

    def initialize(base_url: MAINNET_URL)
      @transport = Transport.new(base_url: base_url)
      @coin_to_asset = nil
      @spot_coin_to_asset = nil
    end

    # ---- Market Data ----

    # Get perpetual metadata (universe, asset info).
    def meta
      post("meta")
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
    def all_mids
      post("allMids")
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

    # ---- User State ----

    # Get user's perpetual account state (positions, margin, etc).
    # @param address [String] user address
    def user_state(address)
      post("clearinghouseState", user: address)
    end

    # Get user's spot account state.
    # @param address [String] user address
    def spot_user_state(address)
      post("spotClearinghouseState", user: address)
    end

    # Get user's open orders.
    # @param address [String] user address
    def open_orders(address)
      post("openOrders", user: address)
    end

    # Get user's open orders with additional frontend info.
    # @param address [String] user address
    def frontend_open_orders(address)
      post("frontendOpenOrders", user: address)
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
    def user_fills_by_time(address, start_time:, end_time: nil)
      req = { user: address, startTime: start_time }
      req[:endTime] = end_time if end_time
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

    # ---- Referrals ----

    # Get referral state for an address.
    # @param address [String] user address
    def referral(address)
      post("referral", user: address)
    end

    # ---- Coin-to-asset mapping (lazy loaded) ----

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

    # Reset cached coin mappings (e.g. after new listings).
    def refresh_coin_mappings!
      @coin_to_asset = nil
      @spot_coin_to_asset = nil
    end

    private

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
  end
end
