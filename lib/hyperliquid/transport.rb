# frozen_string_literal: true

require "faraday"
require "json"

module Hyperliquid
  class Transport
    attr_reader :base_url

    def initialize(base_url: MAINNET_URL)
      @base_url = base_url
      @connection = Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
        f.options.timeout = 30
        f.options.open_timeout = 10
      end
    end

    def post_info(body)
      post("/info", body)
    end

    def post_exchange(body)
      post("/exchange", body)
    end

    private

    def post(path, body)
      response = @connection.post(path) do |req|
        req.body = body
      end
      handle_response(response)
    rescue Faraday::Error => e
      raise Error, "Network error: #{e.message}"
    end

    def handle_response(response)
      case response.status
      when 200
        response.body
      when 400..499
        raise ClientError.new(
          "HTTP #{response.status}: #{error_message(response.body)}",
          status: response.status,
          body: response.body
        )
      when 500..599
        raise ServerError.new(
          "HTTP #{response.status}: #{error_message(response.body)}",
          status: response.status,
          body: response.body
        )
      else
        raise Error, "Unexpected HTTP #{response.status}"
      end
    end

    def error_message(body)
      case body
      when String then body
      when Hash then body["error"] || body.to_s
      else body.to_s
      end
    end
  end
end
