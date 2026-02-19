# frozen_string_literal: true

require "test_helper"

class Hyperliquid::TransportTest < Minitest::Test
  def setup
    @transport = Hyperliquid::Transport.new(base_url: Hyperliquid::MAINNET_URL)
  end

  def test_post_info_success
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .with(body: { type: "allMids" }.to_json)
      .to_return(status: 200, body: { "ETH" => "1800.5" }.to_json, headers: { "Content-Type" => "application/json" })

    result = @transport.post_info({ type: "allMids" })
    assert_equal({ "ETH" => "1800.5" }, result)
  end

  def test_post_exchange_success
    stub_request(:post, "https://api.hyperliquid.xyz/exchange")
      .to_return(status: 200, body: { "status" => "ok" }.to_json, headers: { "Content-Type" => "application/json" })

    result = @transport.post_exchange({ action: {}, nonce: 0, signature: {} })
    assert_equal({ "status" => "ok" }, result)
  end

  def test_client_error
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .to_return(status: 400, body: "Bad Request", headers: { "Content-Type" => "text/plain" })

    error = assert_raises(Hyperliquid::ClientError) do
      @transport.post_info({ type: "invalid" })
    end
    assert_equal 400, error.status
  end

  def test_server_error
    stub_request(:post, "https://api.hyperliquid.xyz/info")
      .to_return(status: 500, body: "Internal Server Error", headers: { "Content-Type" => "text/plain" })

    error = assert_raises(Hyperliquid::ServerError) do
      @transport.post_info({ type: "allMids" })
    end
    assert_equal 500, error.status
  end

  def test_testnet_url
    transport = Hyperliquid::Transport.new(base_url: Hyperliquid::TESTNET_URL)
    assert_equal Hyperliquid::TESTNET_URL, transport.base_url

    stub_request(:post, "https://api.hyperliquid-testnet.xyz/info")
      .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

    transport.post_info({ type: "allMids" })
    assert_requested(:post, "https://api.hyperliquid-testnet.xyz/info")
  end
end
