# frozen_string_literal: true

require "test_helper"

class Hyperliquid::InfoTest < Minitest::Test
  def setup
    @info = Hyperliquid::Info.new(skip_ws: true)
  end

  def test_meta
    stub_info_request("meta", {},
                      { "universe" => [{ "name" => "BTC", "szDecimals" => 5 }, { "name" => "ETH", "szDecimals" => 4 }] })

    result = @info.meta
    assert_equal 2, result["universe"].length
    assert_equal "BTC", result["universe"][0]["name"]
  end

  def test_meta_with_dex
    stub_info_request("meta", { dex: "mydex" },
                      { "universe" => [{ "name" => "CUSTOM", "szDecimals" => 2 }] })

    result = @info.meta(dex: "mydex")
    assert_equal "CUSTOM", result["universe"][0]["name"]
  end

  def test_all_mids
    stub_info_request("allMids", {}, { "ETH" => "1800.5", "BTC" => "45000.0" })

    result = @info.all_mids
    assert_equal "1800.5", result["ETH"]
    assert_equal "45000.0", result["BTC"]
  end

  def test_all_mids_with_dex
    stub_info_request("allMids", { dex: "mydex" }, { "mydex:ETH" => "1800.5" })

    result = @info.all_mids(dex: "mydex")
    assert_equal "1800.5", result["mydex:ETH"]
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

  def test_perp_dexs
    stub_info_request("perpDexs", {}, %w[dex1 dex2])
    result = @info.perp_dexs
    assert_equal %w[dex1 dex2], result
  end

  def test_user_state
    stub_info_request("clearinghouseState", { user: "0xabc" },
                      { "marginSummary" => { "accountValue" => "10000" } })

    result = @info.user_state("0xabc")
    assert_equal "10000", result["marginSummary"]["accountValue"]
  end

  def test_user_state_with_dex
    stub_info_request("clearinghouseState", { user: "0xabc", dex: "mydex" },
                      { "marginSummary" => { "accountValue" => "5000" } })

    result = @info.user_state("0xabc", dex: "mydex")
    assert_equal "5000", result["marginSummary"]["accountValue"]
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

  def test_open_orders_with_dex
    stub_info_request("openOrders", { user: "0xabc", dex: "mydex" }, [])

    result = @info.open_orders("0xabc", dex: "mydex")
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

  def test_user_fills_by_time_with_aggregate
    stub_info_request("userFillsByTime", { user: "0xabc", startTime: 1000, aggregateByTime: true }, [])

    result = @info.user_fills_by_time("0xabc", start_time: 1000, aggregate_by_time: true)
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

  def test_historical_orders
    stub_info_request("historicalOrders", { user: "0xabc" }, [])

    result = @info.historical_orders("0xabc")
    assert_equal [], result
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

  def test_user_staking_summary
    stub_info_request("delegatorSummary", { user: "0xabc" }, { "delegated" => "1000" })
    result = @info.user_staking_summary("0xabc")
    assert_equal "1000", result["delegated"]
  end

  def test_user_staking_delegations
    stub_info_request("delegations", { user: "0xabc" }, [])
    assert_equal [], @info.user_staking_delegations("0xabc")
  end

  def test_user_staking_rewards
    stub_info_request("delegatorRewards", { user: "0xabc" }, [])
    assert_equal [], @info.user_staking_rewards("0xabc")
  end

  def test_delegator_history
    stub_info_request("delegatorHistory", { user: "0xabc" }, [])
    assert_equal [], @info.delegator_history("0xabc")
  end

  def test_referral
    stub_info_request("referral", { user: "0xabc" }, { "code" => "TEST" })
    result = @info.referral("0xabc")
    assert_equal "TEST", result["code"]
  end

  def test_query_user_to_multi_sig_signers
    stub_info_request("userToMultiSigSigners", { user: "0xabc" }, [])
    assert_equal [], @info.query_user_to_multi_sig_signers("0xabc")
  end

  def test_query_perp_deploy_auction_status
    stub_info_request("perpDeployAuctionStatus", {}, { "status" => "active" })
    result = @info.query_perp_deploy_auction_status
    assert_equal "active", result["status"]
  end

  def test_query_spot_deploy_auction_status
    stub_info_request("spotDeployState", { user: "0xabc" }, {})
    @info.query_spot_deploy_auction_status("0xabc")
  end

  def test_query_user_dex_abstraction_state
    stub_info_request("userDexAbstraction", { user: "0xabc" }, { "enabled" => true })
    result = @info.query_user_dex_abstraction_state("0xabc")
    assert_equal true, result["enabled"]
  end

  def test_query_user_abstraction_state
    stub_info_request("userAbstraction", { user: "0xabc" }, { "abstraction" => "disabled" })
    result = @info.query_user_abstraction_state("0xabc")
    assert_equal "disabled", result["abstraction"]
  end

  def test_portfolio
    stub_info_request("portfolio", { user: "0xabc" }, { "performance" => {} })
    result = @info.portfolio("0xabc")
    assert result.key?("performance")
  end

  def test_user_twap_slice_fills
    stub_info_request("userTwapSliceFills", { user: "0xabc" }, [])
    assert_equal [], @info.user_twap_slice_fills("0xabc")
  end

  def test_user_vault_equities
    stub_info_request("userVaultEquities", { user: "0xabc" }, [])
    assert_equal [], @info.user_vault_equities("0xabc")
  end

  def test_user_role
    stub_info_request("userRole", { user: "0xabc" }, { "role" => "user" })
    result = @info.user_role("0xabc")
    assert_equal "user", result["role"]
  end

  def test_extra_agents
    stub_info_request("extraAgents", { user: "0xabc" }, [])
    assert_equal [], @info.extra_agents("0xabc")
  end

  def test_user_rate_limit
    stub_info_request("userRateLimit", { user: "0xabc" }, { "remaining" => 100 })
    result = @info.user_rate_limit("0xabc")
    assert_equal 100, result["remaining"]
  end

  def test_user_funding
    stub_info_request("userFunding", { user: "0xabc", startTime: 1000 }, [])
    assert_equal [], @info.user_funding("0xabc", start_time: 1000)
  end

  def test_user_non_funding_ledger_updates
    stub_info_request("userNonFundingLedgerUpdates", { user: "0xabc", startTime: 1000 }, [])
    assert_equal [], @info.user_non_funding_ledger_updates("0xabc", start_time: 1000)
  end

  def test_funding_history
    stub_info_request("fundingHistory", { coin: "ETH", startTime: 1000 }, [])
    assert_equal [], @info.funding_history("ETH", start_time: 1000)
  end

  def test_name_to_asset
    stub_info_request("meta", {},
                      { "universe" => [{ "name" => "BTC", "szDecimals" => 5 }, { "name" => "ETH", "szDecimals" => 4 }] })
    stub_info_request("spotMeta", {},
                      { "universe" => [{ "name" => "PURR/USDC" }], "tokens" => [] })
    stub_info_request("perpDexs", {}, [])

    assert_equal 0, @info.name_to_asset("BTC")
    assert_equal 1, @info.name_to_asset("ETH")
    assert_equal 10_000, @info.name_to_asset("PURR/USDC")
  end

  def test_name_to_asset_unknown_raises
    stub_info_request("meta", {}, { "universe" => [{ "name" => "BTC", "szDecimals" => 5 }] })
    stub_info_request("spotMeta", {}, { "universe" => [], "tokens" => [] })
    stub_info_request("perpDexs", {}, [])

    assert_raises(Hyperliquid::Error) { @info.name_to_asset("UNKNOWN") }
  end

  def test_asset_to_sz_decimals
    stub_info_request("meta", {},
                      { "universe" => [{ "name" => "BTC", "szDecimals" => 5 }, { "name" => "ETH", "szDecimals" => 4 }] })
    stub_info_request("spotMeta", {}, { "universe" => [], "tokens" => [] })
    stub_info_request("perpDexs", {}, [])

    assert_equal 5, @info.asset_to_sz_decimals(0) # BTC
    assert_equal 4, @info.asset_to_sz_decimals(1) # ETH
  end

  def test_name_to_coin
    stub_info_request("meta", {},
                      { "universe" => [{ "name" => "BTC", "szDecimals" => 5 }] })
    stub_info_request("spotMeta", {}, { "universe" => [], "tokens" => [] })
    stub_info_request("perpDexs", {}, [])

    assert_equal "BTC", @info.name_to_coin("BTC")
  end

  private

  def stub_info_request(type, extra_params, response_body)
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .with(body: { type: type }.merge(extra_params).to_json)
      .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
  end
end
