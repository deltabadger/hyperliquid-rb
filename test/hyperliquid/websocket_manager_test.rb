# frozen_string_literal: true

require "test_helper"

class Hyperliquid::WebsocketManagerTest < Minitest::Test
  # ===========================================================================
  # subscription_to_identifier
  # ===========================================================================

  def test_subscription_to_identifier_all_mids
    assert_equal "allMids",
                 Hyperliquid::WebsocketManager.subscription_to_identifier({ "type" => "allMids" })
  end

  def test_subscription_to_identifier_l2_book
    assert_equal "l2Book:eth",
                 Hyperliquid::WebsocketManager.subscription_to_identifier({ "type" => "l2Book", "coin" => "ETH" })
  end

  def test_subscription_to_identifier_trades
    assert_equal "trades:btc",
                 Hyperliquid::WebsocketManager.subscription_to_identifier({ "type" => "trades", "coin" => "BTC" })
  end

  def test_subscription_to_identifier_user_events
    assert_equal "userEvents",
                 Hyperliquid::WebsocketManager.subscription_to_identifier({ "type" => "userEvents" })
  end

  def test_subscription_to_identifier_user_fills
    assert_equal "userFills:0xabc",
                 Hyperliquid::WebsocketManager.subscription_to_identifier({ "type" => "userFills", "user" => "0xABC" })
  end

  def test_subscription_to_identifier_candle
    assert_equal "candle:eth,1h",
                 Hyperliquid::WebsocketManager.subscription_to_identifier(
                   { "type" => "candle", "coin" => "ETH", "interval" => "1h" }
                 )
  end

  def test_subscription_to_identifier_order_updates
    assert_equal "orderUpdates",
                 Hyperliquid::WebsocketManager.subscription_to_identifier({ "type" => "orderUpdates" })
  end

  def test_subscription_to_identifier_user_fundings
    assert_equal "userFundings:0xabc",
                 Hyperliquid::WebsocketManager.subscription_to_identifier(
                   { "type" => "userFundings", "user" => "0xABC" }
                 )
  end

  def test_subscription_to_identifier_user_non_funding
    assert_equal "userNonFundingLedgerUpdates:0xabc",
                 Hyperliquid::WebsocketManager.subscription_to_identifier(
                   { "type" => "userNonFundingLedgerUpdates", "user" => "0xABC" }
                 )
  end

  def test_subscription_to_identifier_web_data2
    assert_equal "webData2:0xabc",
                 Hyperliquid::WebsocketManager.subscription_to_identifier(
                   { "type" => "webData2", "user" => "0xABC" }
                 )
  end

  def test_subscription_to_identifier_bbo
    assert_equal "bbo:eth",
                 Hyperliquid::WebsocketManager.subscription_to_identifier({ "type" => "bbo", "coin" => "ETH" })
  end

  def test_subscription_to_identifier_active_asset_ctx
    assert_equal "activeAssetCtx:sol",
                 Hyperliquid::WebsocketManager.subscription_to_identifier(
                   { "type" => "activeAssetCtx", "coin" => "SOL" }
                 )
  end

  def test_subscription_to_identifier_active_asset_data
    assert_equal "activeAssetData:eth,0xabc",
                 Hyperliquid::WebsocketManager.subscription_to_identifier(
                   { "type" => "activeAssetData", "coin" => "ETH", "user" => "0xABC" }
                 )
  end

  # ===========================================================================
  # ws_msg_to_identifier
  # ===========================================================================

  def test_ws_msg_pong
    assert_equal "pong",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier({ "channel" => "pong" })
  end

  def test_ws_msg_all_mids
    assert_equal "allMids",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier({ "channel" => "allMids", "data" => {} })
  end

  def test_ws_msg_l2_book
    assert_equal "l2Book:eth",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "l2Book", "data" => { "coin" => "ETH" } }
                 )
  end

  def test_ws_msg_trades
    assert_equal "trades:btc",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "trades", "data" => [{ "coin" => "BTC" }] }
                 )
  end

  def test_ws_msg_trades_empty
    assert_nil Hyperliquid::WebsocketManager.ws_msg_to_identifier(
      { "channel" => "trades", "data" => [] }
    )
  end

  def test_ws_msg_user
    assert_equal "userEvents",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier({ "channel" => "user", "data" => {} })
  end

  def test_ws_msg_user_fills
    assert_equal "userFills:0xabc",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "userFills", "data" => { "user" => "0xABC" } }
                 )
  end

  def test_ws_msg_candle
    assert_equal "candle:eth,1h",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "candle", "data" => { "s" => "ETH", "i" => "1h" } }
                 )
  end

  def test_ws_msg_order_updates
    assert_equal "orderUpdates",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier({ "channel" => "orderUpdates", "data" => {} })
  end

  def test_ws_msg_user_fundings
    assert_equal "userFundings:0xabc",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "userFundings", "data" => { "user" => "0xABC" } }
                 )
  end

  def test_ws_msg_user_non_funding
    assert_equal "userNonFundingLedgerUpdates:0xabc",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "userNonFundingLedgerUpdates", "data" => { "user" => "0xABC" } }
                 )
  end

  def test_ws_msg_web_data2
    assert_equal "webData2:0xabc",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "webData2", "data" => { "user" => "0xABC" } }
                 )
  end

  def test_ws_msg_bbo
    assert_equal "bbo:eth",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "bbo", "data" => { "coin" => "ETH" } }
                 )
  end

  def test_ws_msg_active_asset_ctx
    assert_equal "activeAssetCtx:sol",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "activeAssetCtx", "data" => { "coin" => "SOL" } }
                 )
  end

  def test_ws_msg_active_spot_asset_ctx
    assert_equal "activeAssetCtx:sol",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "activeSpotAssetCtx", "data" => { "coin" => "SOL" } }
                 )
  end

  def test_ws_msg_active_asset_data
    assert_equal "activeAssetData:eth,0xabc",
                 Hyperliquid::WebsocketManager.ws_msg_to_identifier(
                   { "channel" => "activeAssetData", "data" => { "coin" => "ETH", "user" => "0xABC" } }
                 )
  end

  # ===========================================================================
  # Info skip_ws behavior
  # ===========================================================================

  def test_info_subscribe_raises_when_skip_ws
    info = Hyperliquid::Info.new(skip_ws: true)
    assert_raises(RuntimeError) { info.subscribe({ "type" => "allMids" }, proc {}) }
  end

  def test_info_unsubscribe_raises_when_skip_ws
    info = Hyperliquid::Info.new(skip_ws: true)
    assert_raises(RuntimeError) { info.unsubscribe({ "type" => "allMids" }, 1) }
  end

  def test_info_disconnect_raises_when_skip_ws
    info = Hyperliquid::Info.new(skip_ws: true)
    assert_raises(RuntimeError) { info.disconnect_websocket }
  end
end
