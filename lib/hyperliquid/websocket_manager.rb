# frozen_string_literal: true

require "json"
require "websocket-client-simple"

module Hyperliquid
  ActiveSubscription = Struct.new(:callback, :subscription_id)

  class WebsocketManager
    PING_INTERVAL = 50 # seconds

    def initialize(base_url)
      @subscription_id_counter = 0
      @ws_ready = false
      @queued_subscriptions = []
      @active_subscriptions = Hash.new { |h, k| h[k] = [] }
      @mutex = Mutex.new
      @stop_event = false

      ws_url = "ws#{base_url[4..]}/ws"
      @ws_url = ws_url
      @ws = nil
    end

    def start
      manager = self
      @ws = WebSocket::Client::Simple.connect(@ws_url)

      @ws.on :message do |msg|
        manager.send(:handle_message, msg.data)
      end

      @ws.on :open do
        manager.send(:handle_open)
      end

      @ping_thread = Thread.new { send_ping }
    end

    def stop
      @mutex.synchronize { @stop_event = true }
      @ws&.close
      @ping_thread&.join
    end

    def subscribe(subscription, callback, subscription_id: nil)
      @mutex.synchronize do
        if subscription_id.nil?
          @subscription_id_counter += 1
          subscription_id = @subscription_id_counter
        end

        if @ws_ready
          identifier = self.class.subscription_to_identifier(subscription)
          if %w[userEvents orderUpdates].include?(identifier) && !@active_subscriptions[identifier].empty?
            raise NotImplementedError, "Cannot subscribe to #{identifier} multiple times"
          end

          @active_subscriptions[identifier] << ActiveSubscription.new(callback, subscription_id)
          @ws.send(JSON.generate({ "method" => "subscribe", "subscription" => subscription }))
        else
          @queued_subscriptions << [subscription, ActiveSubscription.new(callback, subscription_id)]
        end

        subscription_id
      end
    end

    def unsubscribe(subscription, subscription_id)
      @mutex.synchronize do
        raise NotImplementedError, "Can't unsubscribe before websocket connected" unless @ws_ready

        identifier = self.class.subscription_to_identifier(subscription)
        active = @active_subscriptions[identifier]
        new_active = active.reject { |s| s.subscription_id == subscription_id }
        @ws.send(JSON.generate({ "method" => "unsubscribe", "subscription" => subscription })) if new_active.empty?
        @active_subscriptions[identifier] = new_active
        active.length != new_active.length
      end
    end

    # Maps a subscription request to its identifier string.
    def self.subscription_to_identifier(subscription)
      type = subscription["type"]
      case type
      when "allMids"
        "allMids"
      when "l2Book"
        "l2Book:#{subscription["coin"].downcase}"
      when "trades"
        "trades:#{subscription["coin"].downcase}"
      when "userEvents"
        "userEvents"
      when "userFills"
        "userFills:#{subscription["user"].downcase}"
      when "candle"
        "candle:#{subscription["coin"].downcase},#{subscription["interval"]}"
      when "orderUpdates"
        "orderUpdates"
      when "userFundings"
        "userFundings:#{subscription["user"].downcase}"
      when "userNonFundingLedgerUpdates"
        "userNonFundingLedgerUpdates:#{subscription["user"].downcase}"
      when "webData2"
        "webData2:#{subscription["user"].downcase}"
      when "bbo"
        "bbo:#{subscription["coin"].downcase}"
      when "activeAssetCtx"
        "activeAssetCtx:#{subscription["coin"].downcase}"
      when "activeAssetData"
        "activeAssetData:#{subscription["coin"].downcase},#{subscription["user"].downcase}"
      end
    end

    # Maps an incoming WS message to its identifier string.
    def self.ws_msg_to_identifier(ws_msg)
      channel = ws_msg["channel"]
      case channel
      when "pong"
        "pong"
      when "allMids"
        "allMids"
      when "l2Book"
        "l2Book:#{ws_msg["data"]["coin"].downcase}"
      when "trades"
        trades = ws_msg["data"]
        return nil if trades.empty?

        "trades:#{trades[0]["coin"].downcase}"
      when "user"
        "userEvents"
      when "userFills"
        "userFills:#{ws_msg["data"]["user"].downcase}"
      when "candle"
        "candle:#{ws_msg["data"]["s"].downcase},#{ws_msg["data"]["i"]}"
      when "orderUpdates"
        "orderUpdates"
      when "userFundings"
        "userFundings:#{ws_msg["data"]["user"].downcase}"
      when "userNonFundingLedgerUpdates"
        "userNonFundingLedgerUpdates:#{ws_msg["data"]["user"].downcase}"
      when "webData2"
        "webData2:#{ws_msg["data"]["user"].downcase}"
      when "bbo"
        "bbo:#{ws_msg["data"]["coin"].downcase}"
      when "activeAssetCtx", "activeSpotAssetCtx"
        "activeAssetCtx:#{ws_msg["data"]["coin"].downcase}"
      when "activeAssetData"
        "activeAssetData:#{ws_msg["data"]["coin"].downcase},#{ws_msg["data"]["user"].downcase}"
      end
    end

    private

    def handle_message(data)
      return if data == "Websocket connection established."

      ws_msg = JSON.parse(data)
      identifier = self.class.ws_msg_to_identifier(ws_msg)
      return if identifier == "pong"
      return if identifier.nil?

      active = @mutex.synchronize { @active_subscriptions[identifier].dup }
      if active.empty?
        warn "Websocket message from an unexpected subscription: #{data} #{identifier}"
      else
        active.each { |sub| sub.callback.call(ws_msg) }
      end
    end

    def handle_open
      @mutex.synchronize do
        @ws_ready = true
        @queued_subscriptions.each do |subscription, active_sub|
          subscribe(subscription, active_sub.callback, subscription_id: active_sub.subscription_id)
        end
        @queued_subscriptions.clear
      end
    end

    def send_ping
      loop do
        sleep 1
        elapsed = 0
        loop do
          break if @mutex.synchronize { @stop_event } || elapsed >= PING_INTERVAL

          sleep 1
          elapsed += 1
        end
        break if @mutex.synchronize { @stop_event }

        @ws&.send(JSON.generate({ "method" => "ping" }))
      end
    end
  end
end
