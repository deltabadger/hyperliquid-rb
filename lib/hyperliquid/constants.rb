# frozen_string_literal: true

module Hyperliquid
  MAINNET_URL = "https://api.hyperliquid.xyz"
  TESTNET_URL = "https://api.hyperliquid-testnet.xyz"

  # EIP-712 domain for L1 action signing (phantom agent)
  AGENT_EIP712_DOMAIN = {
    name: "Exchange",
    version: "1",
    chainId: 1337,
    verifyingContract: "0x0000000000000000000000000000000000000000"
  }.freeze

  AGENT_EIP712_TYPES = {
    Agent: [
      { name: "source", type: "string" },
      { name: "connectionId", type: "bytes32" }
    ]
  }.freeze

  # EIP-712 domain for user-signed actions (transfers, withdrawals)
  # chainId is set dynamically from action's signatureChainId
  USER_SIGNED_EIP712_DOMAIN_NAME = "HyperliquidSignTransaction"
  USER_SIGNED_EIP712_DOMAIN_VERSION = "1"
  USER_SIGNED_CHAIN_ID = 0x66eee # 421614 decimal

  # User-signed action EIP-712 type definitions
  USER_SIGNED_TYPES = {
    "UsdSend" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "destination", type: "string" },
      { name: "amount", type: "string" },
      { name: "time", type: "uint64" }
    ],
    "SpotSend" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "destination", type: "string" },
      { name: "token", type: "string" },
      { name: "amount", type: "string" },
      { name: "time", type: "uint64" }
    ],
    "Withdraw" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "destination", type: "string" },
      { name: "amount", type: "string" },
      { name: "time", type: "uint64" }
    ],
    "UsdClassTransfer" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "amount", type: "string" },
      { name: "toPerp", type: "bool" },
      { name: "nonce", type: "uint64" }
    ],
    "SendAsset" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "destination", type: "string" },
      { name: "sourceDex", type: "string" },
      { name: "destinationDex", type: "string" },
      { name: "token", type: "string" },
      { name: "amount", type: "string" },
      { name: "fromSubAccount", type: "string" },
      { name: "nonce", type: "uint64" }
    ],
    "ApproveAgent" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "agentAddress", type: "address" },
      { name: "agentName", type: "string" },
      { name: "nonce", type: "uint64" }
    ],
    "ApproveBuilderFee" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "maxFeeRate", type: "string" },
      { name: "builder", type: "address" },
      { name: "nonce", type: "uint64" }
    ],
    "TokenDelegate" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "validator", type: "address" },
      { name: "wei", type: "uint64" },
      { name: "isUndelegate", type: "bool" },
      { name: "nonce", type: "uint64" }
    ],
    "ConvertToMultiSigUser" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "signers", type: "string" },
      { name: "nonce", type: "uint64" }
    ],
    "SendMultiSig" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "multiSigActionHash", type: "bytes32" },
      { name: "nonce", type: "uint64" }
    ],
    "UserDexAbstraction" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "user", type: "address" },
      { name: "enabled", type: "bool" },
      { name: "nonce", type: "uint64" }
    ],
    "UserSetAbstraction" => [
      { name: "hyperliquidChain", type: "string" },
      { name: "user", type: "address" },
      { name: "abstraction", type: "string" },
      { name: "nonce", type: "uint64" }
    ]
  }.freeze
end
