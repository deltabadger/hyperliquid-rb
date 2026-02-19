# frozen_string_literal: true

require "eth"
require "msgpack"

module Hyperliquid
  class Signer
    attr_reader :key, :is_mainnet

    # @param private_key [String] hex private key (with or without 0x prefix)
    # @param base_url [String] API URL to determine mainnet vs testnet
    def initialize(private_key:, base_url: MAINNET_URL)
      hex = private_key.delete_prefix("0x")
      @key = Eth::Key.new(priv: hex)
      @is_mainnet = base_url == MAINNET_URL
    end

    def address
      @key.address.to_s
    end

    # Sign an L1 action (orders, cancels, leverage, etc.)
    # Returns { r: "0x...", s: "0x...", v: Integer }
    def sign_l1_action(action, nonce:, vault_address: nil, expires_after: nil)
      hash = action_hash(action, nonce: nonce, vault_address: vault_address, expires_after: expires_after)
      phantom = { source: (@is_mainnet ? "a" : "b"), connectionId: hash }
      typed_data = build_agent_typed_data(phantom)
      sign_typed_data(typed_data)
    end

    # Sign a user-signed action (transfers, withdrawals, approvals, etc.)
    # @param action [Hash] the action payload (string keys, will be modified)
    # @param primary_type [String] e.g. "UsdSend", "Withdraw"
    # @param payload_types [Array] EIP-712 field definitions for the primary type
    def sign_user_signed_action(action, primary_type:, payload_types:)
      action["signatureChainId"] = "0x66eee"
      action["hyperliquidChain"] = @is_mainnet ? "Mainnet" : "Testnet"

      typed_data = build_user_signed_typed_data(action, primary_type: primary_type, payload_types: payload_types)
      sign_typed_data(typed_data)
    end

    # Compute the action hash for L1 actions.
    # msgpack(action) + nonce(8B) + vault_flag(1B) + [vault_addr(20B)] + [0x00 + expires(8B)]
    def action_hash(action, nonce:, vault_address: nil, expires_after: nil)
      data = MessagePack.pack(action)
      data += [nonce].pack("Q>")

      if vault_address.nil?
        data += "\x00".b
      else
        data += "\x01".b
        data += Utils.address_to_bytes(vault_address)
      end

      if expires_after
        data += "\x00".b
        data += [expires_after].pack("Q>")
      end

      Eth::Util.keccak256(data)
    end

    private

    def build_agent_typed_data(phantom_agent)
      {
        types: {
          EIP712Domain: [
            { name: "name", type: "string" },
            { name: "version", type: "string" },
            { name: "chainId", type: "uint256" },
            { name: "verifyingContract", type: "address" }
          ],
          Agent: [
            { name: "source", type: "string" },
            { name: "connectionId", type: "bytes32" }
          ]
        },
        primaryType: "Agent",
        domain: {
          name: "Exchange",
          version: "1",
          chainId: 1337,
          verifyingContract: "0x0000000000000000000000000000000000000000"
        },
        message: phantom_agent
      }
    end

    def build_user_signed_typed_data(action, primary_type:, payload_types:)
      chain_id = action["signatureChainId"].to_i(16)

      # Build message from action, using only the fields defined in payload_types
      message = {}
      payload_types.each do |field|
        name = field[:name]
        message[name.to_sym] = action[name]
      end

      type_name = "HyperliquidTransaction:#{primary_type}"

      {
        types: {
          EIP712Domain: [
            { name: "name", type: "string" },
            { name: "version", type: "string" },
            { name: "chainId", type: "uint256" },
            { name: "verifyingContract", type: "address" }
          ],
          type_name.to_sym => payload_types
        },
        primaryType: type_name,
        domain: {
          name: "HyperliquidSignTransaction",
          version: "1",
          chainId: chain_id,
          verifyingContract: "0x0000000000000000000000000000000000000000"
        },
        message: message
      }
    end

    def sign_typed_data(typed_data)
      hash = Eth::Eip712.hash(typed_data)
      sig_hex = @key.sign(hash)
      sig_bytes = [sig_hex].pack("H*")

      r_int = sig_bytes[0, 32].unpack1("H*").to_i(16)
      s_int = sig_bytes[32, 32].unpack1("H*").to_i(16)
      v = sig_bytes[64].unpack1("C")

      { r: "0x#{r_int.to_s(16)}", s: "0x#{s_int.to_s(16)}", v: v }
    end
  end
end
