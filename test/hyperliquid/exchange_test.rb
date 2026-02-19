# frozen_string_literal: true

require "test_helper"

class Hyperliquid::ExchangeTest < Minitest::Test
  PRIVATE_KEY = "0x0123456789012345678901234567890123456789012345678901234567890123"

  def setup
    @exchange = Hyperliquid::Exchange.new(private_key: PRIVATE_KEY)

    # Stub meta for coin_to_asset mapping
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .with(body: { type: "meta" }.to_json)
      .to_return(
        status: 200,
        body: { "universe" => [{ "name" => "BTC" }, { "name" => "ETH" }, { "name" => "SOL" }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub exchange endpoint (accepts all)
    stub_request(:post, "https://api.hyperliquid.xyz/exchange")
      .to_return(
        status: 200,
        body: { "status" => "ok",
                "response" => { "type" => "order",
                                "data" => { "statuses" => [{ "resting" => { "oid" => 123 } }] } } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def test_single_order
    result = @exchange.order("ETH", is_buy: true, sz: 1.0, limit_px: 1800.0,
                                    order_type: { limit: { "tif" => "Gtc" } })

    assert_equal "ok", result["status"]
    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      action = body["action"]
      assert_equal "order", action["type"]
      assert_equal 1, action["orders"].length

      wire = action["orders"][0]
      assert_equal 1, wire["a"] # ETH = index 1
      assert_equal true, wire["b"]
      assert_equal "1800", wire["p"]
      assert_equal "1", wire["s"]
      assert_equal false, wire["r"]
      true
    end
  end

  def test_order_with_cloid
    cloid = Hyperliquid::Cloid.from_int(42)
    @exchange.order("BTC", is_buy: false, sz: 0.5, limit_px: 45000.0,
                           order_type: { limit: { "tif" => "Ioc" } }, cloid: cloid)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      wire = body["action"]["orders"][0]
      assert_equal 0, wire["a"] # BTC = index 0
      assert_equal false, wire["b"]
      assert_equal "0x0000000000000000000000000000002a", wire["c"]
      true
    end
  end

  def test_bulk_orders
    orders = [
      { coin: "ETH", is_buy: true, sz: 1.0, limit_px: 1800.0,
        order_type: { limit: { "tif" => "Gtc" } }, reduce_only: false },
      { coin: "BTC", is_buy: false, sz: 0.1, limit_px: 45000.0,
        order_type: { limit: { "tif" => "Gtc" } }, reduce_only: false }
    ]
    @exchange.bulk_orders(orders)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal 2, body["action"]["orders"].length
      assert_equal 1, body["action"]["orders"][0]["a"] # ETH
      assert_equal 0, body["action"]["orders"][1]["a"] # BTC
      true
    end
  end

  def test_cancel_by_oid
    @exchange.cancel([{ coin: "ETH", oid: 123 }])

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "cancel", body["action"]["type"]
      assert_equal [{ "a" => 1, "o" => 123 }], body["action"]["cancels"]
      true
    end
  end

  def test_cancel_by_cloid
    cloid = Hyperliquid::Cloid.from_int(99)
    @exchange.cancel_by_cloid([{ coin: "ETH", cloid: cloid }])

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "cancelByCloid", body["action"]["type"]
      assert_equal 1, body["action"]["cancels"][0]["asset"]
      assert_equal "0x00000000000000000000000000000063", body["action"]["cancels"][0]["cloid"]
      true
    end
  end

  def test_modify_order
    @exchange.modify_order(456, coin: "ETH", is_buy: true, sz: 2.0, limit_px: 1850.0,
                                order_type: { limit: { "tif" => "Gtc" } })

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "batchModify", body["action"]["type"]
      mod = body["action"]["modifies"][0]
      assert_equal 456, mod["oid"]
      assert_equal "1850", mod["order"]["p"]
      true
    end
  end

  def test_schedule_cancel_with_time
    @exchange.schedule_cancel(time: 123_456_789)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "scheduleCancel", body["action"]["type"]
      assert_equal 123_456_789, body["action"]["time"]
      true
    end
  end

  def test_schedule_cancel_without_time
    @exchange.schedule_cancel

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "scheduleCancel", body["action"]["type"]
      refute body["action"].key?("time")
      true
    end
  end

  def test_update_leverage
    @exchange.update_leverage("ETH", leverage: 10, is_cross: true)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "updateLeverage", body["action"]["type"]
      assert_equal 1, body["action"]["asset"]
      assert_equal true, body["action"]["isCross"]
      assert_equal 10, body["action"]["leverage"]
      true
    end
  end

  def test_update_isolated_margin
    @exchange.update_isolated_margin("ETH", is_buy: true, amount: 100.0)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "updateIsolatedMargin", body["action"]["type"]
      assert_equal 100_000_000, body["action"]["ntli"]
      true
    end
  end

  def test_create_sub_account
    @exchange.create_sub_account(name: "test")

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "createSubAccount", body["action"]["type"]
      assert_equal "test", body["action"]["name"]
      true
    end
  end

  def test_sub_account_transfer
    @exchange.sub_account_transfer(
      sub_account_user: "0x1234",
      is_deposit: true,
      usd: 100
    )

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "subAccountTransfer", body["action"]["type"]
      assert_equal "0x1234", body["action"]["subAccountUser"]
      assert_equal true, body["action"]["isDeposit"]
      assert_equal 100, body["action"]["usd"]
      true
    end
  end

  def test_usd_transfer
    @exchange.usd_transfer("0xdest", amount: 100.0)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "usdSend", body["action"]["type"]
      assert_equal "0xdest", body["action"]["destination"]
      assert_equal "100", body["action"]["amount"]
      assert_equal "0x66eee", body["action"]["signatureChainId"]
      assert_equal "Mainnet", body["action"]["hyperliquidChain"]
      true
    end
  end

  def test_withdraw_from_bridge
    @exchange.withdraw_from_bridge("0xdest", amount: 50.5)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "withdraw3", body["action"]["type"]
      assert_equal "50.5", body["action"]["amount"]
      true
    end
  end

  def test_usd_class_transfer
    @exchange.usd_class_transfer(amount: 200.0, to_perp: true)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "usdClassTransfer", body["action"]["type"]
      assert_equal "200", body["action"]["amount"]
      assert_equal true, body["action"]["toPerp"]
      true
    end
  end

  def test_approve_agent
    agent_addr = "0x5e9ee1089755c3435139848e47e6635505d5a13a"
    @exchange.approve_agent(agent_address: agent_addr, agent_name: "mybot")

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "approveAgent", body["action"]["type"]
      assert_equal agent_addr, body["action"]["agentAddress"]
      assert_equal "mybot", body["action"]["agentName"]
      true
    end
  end

  def test_approve_builder_fee
    builder_addr = "0x5e9ee1089755c3435139848e47e6635505d5a13a"
    @exchange.approve_builder_fee(builder: builder_addr, max_fee_rate: "0.001")

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "approveBuilderFee", body["action"]["type"]
      assert_equal "0.001", body["action"]["maxFeeRate"]
      assert_equal builder_addr, body["action"]["builder"]
      true
    end
  end

  def test_twap_order
    @exchange.twap_order("ETH", is_buy: true, sz: 10.0, minutes: 30)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "twapOrder", body["action"]["type"]
      twap = body["action"]["twap"]
      assert_equal 1, twap["a"]
      assert_equal true, twap["b"]
      assert_equal "10", twap["s"]
      assert_equal false, twap["r"]
      assert_equal 30, twap["m"]
      assert_equal true, twap["t"]
      true
    end
  end

  def test_market_open
    # Stub allMids
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .with(body: { type: "allMids" }.to_json)
      .to_return(
        status: 200,
        body: { "ETH" => "1800.0" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @exchange.market_open("ETH", is_buy: true, sz: 1.0, slippage: 0.05)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      wire = body["action"]["orders"][0]
      # 1800 * 1.05 = 1890.0
      assert_equal "1890", wire["p"]
      assert_equal({ "limit" => { "tif" => "Ioc" } }, wire["t"])
      true
    end
  end

  def test_vault_address_in_payload
    exchange = Hyperliquid::Exchange.new(
      private_key: PRIVATE_KEY,
      vault_address: "0xmyvault"
    )

    exchange.order("ETH", is_buy: true, sz: 1.0, limit_px: 1800.0,
                          order_type: { limit: { "tif" => "Gtc" } })

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "0xmyvault", body["vaultAddress"]
      true
    end
  end

  def test_signature_present
    @exchange.order("ETH", is_buy: true, sz: 1.0, limit_px: 1800.0,
                           order_type: { limit: { "tif" => "Gtc" } })

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      sig = body["signature"]
      assert sig["r"].start_with?("0x")
      assert sig["s"].start_with?("0x")
      assert [27, 28].include?(sig["v"])
      true
    end
  end
end
