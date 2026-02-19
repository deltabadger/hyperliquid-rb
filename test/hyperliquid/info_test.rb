# frozen_string_literal: true

require "test_helper"

class Hyperliquid::InfoTest < Minitest::Test
  def setup
    @info = Hyperliquid::Info.new
  end

  def test_meta
    stub_info_request("meta", {},
                      { "universe" => [{ "name" => "BTC", "szDecimals" => 5 }, { "name" => "ETH", "szDecimals" => 4 }] })

    result = @info.meta
    assert_equal 2, result["universe"].length
    assert_equal "BTC", result["universe"][0]["name"]
  end

  def test_all_mids
    stub_info_request("allMids", {}, { "ETH" => "1800.5", "BTC" => "45000.0" })

    result = @info.all_mids
    assert_equal "1800.5", result["ETH"]
    assert_equal "45000.0", result["BTC"]
  end

  def test_l2_snapshot
    stub_info_request("l2Book", { coin: "ETH", nSigFigs: 10 },
                      { "levels" => [[], []] })

    result = @info.l2_snapshot("ETH")
    assert result.key?("levels")
  end

  def test_candles_snapshot
    stub_info_request("candleSnapshot",
                      { req: { coin: "ETH", interval: "1h", startTime: 1000, endTime: 2000 } },
                      [{ "t" => 1000, "o" => "1800", "h" => "1810", "l" => "1790", "c" => "1805" }])

    result = @info.candles_snapshot("ETH", interval: "1h", start_time: 1000, end_time: 2000)
    assert_equal 1, result.length
  end

  def test_user_state
    stub_info_request("clearinghouseState", { user: "0xabc" },
                      { "marginSummary" => { "accountValue" => "10000" } })

    result = @info.user_state("0xabc")
    assert_equal "10000", result["marginSummary"]["accountValue"]
  end

  def test_spot_user_state
    stub_info_request("spotClearinghouseState", { user: "0xabc" },
                      { "balances" => [] })

    result = @info.spot_user_state("0xabc")
    assert result.key?("balances")
  end

  def test_open_orders
    stub_info_request("openOrders", { user: "0xabc" }, [])

    result = @info.open_orders("0xabc")
    assert_equal [], result
  end

  def test_frontend_open_orders
    stub_info_request("frontendOpenOrders", { user: "0xabc" }, [])

    result = @info.frontend_open_orders("0xabc")
    assert_equal [], result
  end

  def test_user_fills
    stub_info_request("userFills", { user: "0xabc" }, [])

    result = @info.user_fills("0xabc")
    assert_equal [], result
  end

  def test_user_fills_by_time
    stub_info_request("userFillsByTime", { user: "0xabc", startTime: 1000 }, [])

    result = @info.user_fills_by_time("0xabc", start_time: 1000)
    assert_equal [], result
  end

  def test_user_fees
    stub_info_request("userFees", { user: "0xabc" }, { "feeSchedule" => {} })

    result = @info.user_fees("0xabc")
    assert result.key?("feeSchedule")
  end

  def test_order_status
    stub_info_request("orderStatus", { user: "0xabc", oid: 123 },
                      { "status" => "filled" })

    result = @info.order_status("0xabc", 123)
    assert_equal "filled", result["status"]
  end

  def test_coin_to_asset_mapping
    stub_info_request("meta", {},
                      { "universe" => [{ "name" => "BTC" }, { "name" => "ETH" }, { "name" => "SOL" }] })

    assert_equal 0, @info.coin_to_asset("BTC")
    assert_equal 1, @info.coin_to_asset("ETH")
    assert_equal 2, @info.coin_to_asset("SOL")
  end

  def test_coin_to_asset_unknown_raises
    stub_info_request("meta", {}, { "universe" => [{ "name" => "BTC" }] })

    assert_raises(Hyperliquid::Error) { @info.coin_to_asset("UNKNOWN") }
  end

  def test_spot_coin_to_asset_mapping
    stub_info_request("spotMeta", {},
                      { "universe" => [{ "name" => "PURR/USDC" }, { "name" => "HYPE/USDC" }] })

    assert_equal 10_000, @info.spot_coin_to_asset("PURR/USDC")
    assert_equal 10_001, @info.spot_coin_to_asset("HYPE/USDC")
  end

  def test_sub_accounts
    stub_info_request("subAccounts", { user: "0xabc" }, [])
    assert_equal [], @info.sub_accounts("0xabc")
  end

  def test_predicted_fundings
    stub_info_request("predictedFundings", {}, [])
    assert_equal [], @info.predicted_fundings
  end

  private

  def stub_info_request(type, extra_params, response_body)
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .with(body: { type: type }.merge(extra_params).to_json)
      .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
  end
end
