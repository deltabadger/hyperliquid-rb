# frozen_string_literal: true

require_relative "lib/hyperliquid/version"

Gem::Specification.new do |spec|
  spec.name = "hyperliquid"
  spec.version = Hyperliquid::VERSION
  spec.authors = ["Deltabadger"]
  spec.email = ["hello@deltabadger.com"]

  spec.summary = "Ruby SDK for the Hyperliquid DEX API"
  spec.description = "Complete Ruby SDK for Hyperliquid — trading, market data, EIP-712 signing, and WebSocket subscriptions."
  spec.homepage = "https://github.com/deltabadger/hyperliquid-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "eth", "~> 0.5.17"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "msgpack", "~> 1.7"
  spec.add_dependency "websocket-client-simple", "~> 0.9"
end
