# frozen_string_literal: true

require "test_helper"

class Hyperliquid::ExchangeTest < Minitest::Test
  PRIVATE_KEY = "0x0123456789012345678901234567890123456789012345678901234567890123"

  def setup
    @exchange = Hyperliquid::Exchange.new(private_key: PRIVATE_KEY, skip_ws: true)

    stub_all_info_endpoints

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
    @exchange.cancel("ETH", 123)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "cancel", body["action"]["type"]
      assert_equal [{ "a" => 1, "o" => 123 }], body["action"]["cancels"]
      true
    end
  end

  def test_bulk_cancel
    @exchange.bulk_cancel([{ coin: "ETH", oid: 123 }])

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "cancel", body["action"]["type"]
      assert_equal [{ "a" => 1, "o" => 123 }], body["action"]["cancels"]
      true
    end
  end

  def test_cancel_by_cloid
    cloid = Hyperliquid::Cloid.from_int(99)
    @exchange.cancel_by_cloid("ETH", cloid)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "cancelByCloid", body["action"]["type"]
      assert_equal 1, body["action"]["cancels"][0]["asset"]
      assert_equal "0x00000000000000000000000000000063", body["action"]["cancels"][0]["cloid"]
      true
    end
  end

  def test_bulk_cancel_by_cloid
    cloid = Hyperliquid::Cloid.from_int(99)
    @exchange.bulk_cancel_by_cloid([{ coin: "ETH", cloid: cloid }])

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
      assert_equal "100.0", body["action"]["amount"]
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
      assert_equal "200.0", body["action"]["amount"]
      assert_equal true, body["action"]["toPerp"]
      true
    end
  end

  def test_approve_agent
    result, agent_key = @exchange.approve_agent(name: "mybot")

    assert_equal "ok", result["status"]
    assert agent_key.start_with?("0x")
    assert_equal 66, agent_key.length # 0x + 64 hex chars

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "approveAgent", body["action"]["type"]
      assert body["action"]["agentAddress"].start_with?("0x")
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
      vault_address: "0xmyvault",
      skip_ws: true
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

  # ---- New method tests ----

  def test_set_referrer
    @exchange.set_referrer("MYCODE")

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "setReferrer", body["action"]["type"]
      assert_equal "MYCODE", body["action"]["code"]
      true
    end
  end

  def test_send_asset
    @exchange.send_asset("0xdest", source_dex: "dex1", destination_dex: "dex2", token: "USDC", amount: 100.0)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "sendAsset", body["action"]["type"]
      assert_equal "0xdest", body["action"]["destination"]
      assert_equal "dex1", body["action"]["sourceDex"]
      assert_equal "dex2", body["action"]["destinationDex"]
      assert_equal "USDC", body["action"]["token"]
      assert_equal "100.0", body["action"]["amount"]
      assert_nil body["vaultAddress"] # sendAsset should not have vaultAddress
      true
    end
  end

  def test_vault_usd_transfer
    @exchange.vault_usd_transfer(vault_address: "0xvault", is_deposit: true, usd: 1000)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "vaultTransfer", body["action"]["type"]
      assert_equal "0xvault", body["action"]["vaultAddress"]
      assert_equal true, body["action"]["isDeposit"]
      assert_equal 1000, body["action"]["usd"]
      true
    end
  end

  def test_convert_to_multi_sig_user
    users = %w[0xuser2 0xuser1]
    @exchange.convert_to_multi_sig_user(authorized_users: users, threshold: 2)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "convertToMultiSigUser", body["action"]["type"]
      signers = JSON.parse(body["action"]["signers"])
      assert_equal %w[0xuser1 0xuser2], signers["authorizedUsers"] # sorted
      assert_equal 2, signers["threshold"]
      true
    end
  end

  def test_use_big_blocks
    @exchange.use_big_blocks(true)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "evmUserModify", body["action"]["type"]
      assert_equal true, body["action"]["usingBigBlocks"]
      true
    end
  end

  def test_agent_enable_dex_abstraction
    @exchange.agent_enable_dex_abstraction

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "agentEnableDexAbstraction", body["action"]["type"]
      true
    end
  end

  def test_agent_set_abstraction
    @exchange.agent_set_abstraction("u")

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "agentSetAbstraction", body["action"]["type"]
      assert_equal "u", body["action"]["abstraction"]
      true
    end
  end

  def test_user_dex_abstraction
    user_addr = "0x5e9ee1089755c3435139848e47e6635505d5a13a"
    @exchange.user_dex_abstraction(user_addr, enabled: true)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "userDexAbstraction", body["action"]["type"]
      assert_equal user_addr, body["action"]["user"]
      assert_equal true, body["action"]["enabled"]
      true
    end
  end

  def test_user_set_abstraction
    user_addr = "0x5e9ee1089755c3435139848e47e6635505d5a13a"
    @exchange.user_set_abstraction(user_addr, abstraction: "unifiedAccount")

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "userSetAbstraction", body["action"]["type"]
      assert_equal user_addr, body["action"]["user"]
      assert_equal "unifiedAccount", body["action"]["abstraction"]
      true
    end
  end

  def test_noop
    @exchange.noop(12345)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "noop", body["action"]["type"]
      assert_equal 12345, body["nonce"]
      true
    end
  end

  def test_spot_deploy_register_token
    @exchange.spot_deploy_register_token(
      token_name: "TEST", sz_decimals: 2, wei_decimals: 18, max_gas: 100, full_name: "Test Token"
    )

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "spotDeploy", body["action"]["type"]
      reg = body["action"]["registerToken2"]
      assert_equal "TEST", reg["spec"]["name"]
      assert_equal 2, reg["spec"]["szDecimals"]
      assert_equal 18, reg["spec"]["weiDecimals"]
      assert_equal 100, reg["maxGas"]
      assert_equal "Test Token", reg["fullName"]
      true
    end
  end

  def test_spot_deploy_genesis
    @exchange.spot_deploy_genesis(42, max_supply: "1000000", no_hyperliquidity: true)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "spotDeploy", body["action"]["type"]
      genesis = body["action"]["genesis"]
      assert_equal 42, genesis["token"]
      assert_equal "1000000", genesis["maxSupply"]
      assert_equal true, genesis["noHyperliquidity"]
      true
    end
  end

  def test_spot_deploy_register_spot
    @exchange.spot_deploy_register_spot(base_token: 1, quote_token: 0)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "spotDeploy", body["action"]["type"]
      assert_equal [1, 0], body["action"]["registerSpot"]["tokens"]
      true
    end
  end

  def test_c_signer_unjail_self
    @exchange.c_signer_unjail_self

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "CSignerAction", body["action"]["type"]
      assert body["action"].key?("unjailSelf")
      true
    end
  end

  def test_c_validator_unregister
    @exchange.c_validator_unregister

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "CValidatorAction", body["action"]["type"]
      assert body["action"].key?("unregister")
      true
    end
  end

  def test_token_delegate
    validator = "0x5e9ee1089755c3435139848e47e6635505d5a13a"
    @exchange.token_delegate(validator: validator, wei: 1000, is_undelegate: false)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "tokenDelegate", body["action"]["type"]
      assert_equal validator, body["action"]["validator"]
      assert_equal 1000, body["action"]["wei"]
      assert_equal false, body["action"]["isUndelegate"]
      true
    end
  end

  def test_spot_transfer
    @exchange.spot_transfer("0xdest", token: "USDC", amount: 50.0)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "spotSend", body["action"]["type"]
      assert_equal "0xdest", body["action"]["destination"]
      assert_equal "USDC", body["action"]["token"]
      assert_equal "50.0", body["action"]["amount"]
      true
    end
  end

  def test_sub_account_spot_transfer
    @exchange.sub_account_spot_transfer(
      sub_account_user: "0xsub", is_deposit: true, token: "ETH", amount: 1.5
    )

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "subAccountSpotTransfer", body["action"]["type"]
      assert_equal "0xsub", body["action"]["subAccountUser"]
      assert_equal true, body["action"]["isDeposit"]
      assert_equal "ETH", body["action"]["token"]
      assert_equal "1.5", body["action"]["amount"]
      true
    end
  end

  def test_set_expires_after
    @exchange.set_expires_after(1234567890)

    @exchange.order("ETH", is_buy: true, sz: 1.0, limit_px: 1800.0,
                           order_type: { limit: { "tif" => "Gtc" } })

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal 1234567890, body["expiresAfter"]
      true
    end

    # Clear it
    @exchange.set_expires_after(nil)
  end

  def test_usd_class_transfer_no_vault_address
    @exchange.usd_class_transfer(amount: 200.0, to_perp: true)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_nil body["vaultAddress"]
      true
    end
  end

  def test_twap_cancel
    @exchange.twap_cancel("ETH", twap_id: 42)

    assert_requested(:post, "https://api.hyperliquid.xyz/exchange") do |req|
      body = JSON.parse(req.body)
      assert_equal "twapCancel", body["action"]["type"]
      assert_equal 1, body["action"]["a"]
      assert_equal 42, body["action"]["t"]
      true
    end
  end

  private

  def stub_all_info_endpoints
    # Stub meta
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .with(body: { type: "meta" }.to_json)
      .to_return(
        status: 200,
        body: { "universe" => [
          { "name" => "BTC", "szDecimals" => 5 },
          { "name" => "ETH", "szDecimals" => 4 },
          { "name" => "SOL", "szDecimals" => 2 }
        ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub spotMeta
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .with(body: { type: "spotMeta" }.to_json)
      .to_return(
        status: 200,
        body: { "universe" => [], "tokens" => [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub perpDexs
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .with(body: { type: "perpDexs" }.to_json)
      .to_return(
        status: 200,
        body: [].to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
