# Hyperliquid Ruby SDK

[![Gem Version](https://img.shields.io/gem/v/hyperliquid-rb)](https://rubygems.org/gems/hyperliquid-rb)
[![CI](https://github.com/deltabadger/hyperliquid-rb/actions/workflows/ci.yml/badge.svg)](https://github.com/deltabadger/hyperliquid-rb/actions)
[![License](https://img.shields.io/github/license/deltabadger/hyperliquid-rb)](LICENSE.txt)

Complete Ruby SDK for the [Hyperliquid](https://hyperliquid.xyz) DEX. Covers 100% of the official Python SDK — trading, market data, EIP-712 signing, WebSocket subscriptions, and account management.

Verified with 314 tests including 141 cross-library test vectors generated from the official Python SDK to ensure byte-identical signing output.

## Installation

```ruby
gem "hyperliquid-rb"
```

### System Dependencies

The `eth` gem requires `libsecp256k1`:

```bash
# macOS
brew install secp256k1

# Ubuntu/Debian
apt-get install libsecp256k1-dev
```

## Quick Start

### Read-Only (no wallet needed)

```ruby
require "hyperliquid"

info = Hyperliquid::Info.new(skip_ws: true)

info.all_mids              # => {"ETH" => "1800.5", "BTC" => "45000.0", ...}
info.meta                  # Perpetual market metadata
info.l2_snapshot("ETH")    # Order book
info.user_state("0x...")   # Positions and margin
info.open_orders("0x...")  # Open orders
```

### Trading

```ruby
exchange = Hyperliquid::Exchange.new(private_key: "0x...")

# Limit order
exchange.order("ETH",
  is_buy: true,
  sz: 1.0,
  limit_px: 1800.0,
  order_type: { limit: { "tif" => "Gtc" } }
)

# Market buy with 5% slippage
exchange.market_open("ETH", is_buy: true, sz: 1.0)

# Close entire position at market
exchange.market_close("ETH")

# Cancel by order ID
exchange.cancel("ETH", 123)

# Cancel by client order ID
exchange.cancel_by_cloid("ETH", cloid)
```

### Testnet

```ruby
info = Hyperliquid::Info.new(base_url: Hyperliquid::TESTNET_URL, skip_ws: true)
exchange = Hyperliquid::Exchange.new(
  private_key: "0x...",
  base_url: Hyperliquid::TESTNET_URL
)
```

### WebSocket Subscriptions

```ruby
info = Hyperliquid::Info.new

# Subscribe to all mid prices
sub_id = info.subscribe(
  { "type" => "allMids" },
  ->(msg) { puts msg["data"] }
)

# Subscribe to order book
info.subscribe(
  { "type" => "l2Book", "coin" => "ETH" },
  ->(msg) { puts msg["data"]["levels"] }
)

# Subscribe to user events
info.subscribe(
  { "type" => "userEvents", "user" => "0x..." },
  ->(msg) { puts msg }
)

# Unsubscribe
info.unsubscribe({ "type" => "allMids" }, sub_id)

# Disconnect
info.disconnect_websocket
```

WebSocket subscription types: `allMids`, `l2Book`, `trades`, `bbo`, `candle`, `userEvents`, `userFills`, `orderUpdates`, `userFundings`, `userNonFundingLedgerUpdates`, `webData2`, `activeAssetCtx`, `activeAssetData`.

### Vault Trading

```ruby
exchange = Hyperliquid::Exchange.new(
  private_key: "0x...",
  vault_address: "0xvault..."
)
# All subsequent orders go through the vault
```

### Agent Trading

```ruby
# Approve an agent (generates a new key)
result, agent_key = exchange.approve_agent(name: "my-bot")

# Trade as agent
agent_exchange = Hyperliquid::Exchange.new(
  private_key: agent_key,
  account_address: "0xowner..."
)
```

## API Reference

### `Hyperliquid::Info`

Read-only API — no private key required.

```ruby
info = Hyperliquid::Info.new(
  base_url: Hyperliquid::MAINNET_URL,  # or TESTNET_URL
  skip_ws: false                        # set true to disable WebSocket
)
```

#### Market Data

| Method | Description |
|--------|-------------|
| `meta(dex:)` | Perpetual metadata (universe, asset info) |
| `spot_meta` | Spot market metadata |
| `meta_and_asset_ctxs` | Perp metadata with live contexts (funding, OI) |
| `spot_meta_and_asset_ctxs` | Spot metadata with live contexts |
| `all_mids(dex:)` | All mid prices |
| `l2_snapshot(coin, n_levels:)` | L2 order book |
| `candles_snapshot(coin, interval:, start_time:, end_time:)` | Candle data |
| `perp_dexs` | List of perp dexes |

#### User State

| Method | Description |
|--------|-------------|
| `user_state(address, dex:)` | Perpetual account state |
| `spot_user_state(address)` | Spot account state |
| `open_orders(address, dex:)` | Open orders |
| `frontend_open_orders(address, dex:)` | Open orders with frontend info |
| `user_fills(address)` | Trade history |
| `user_fills_by_time(address, start_time:, end_time:, aggregate_by_time:)` | Fills by time range |
| `user_fees(address)` | Fee rates and volume |
| `user_funding(address, start_time:, end_time:)` | User funding history |
| `user_non_funding_ledger_updates(address, start_time:, end_time:)` | Non-funding ledger updates |
| `user_rate_limit(address)` | API rate limit status |
| `user_role(address)` | User role and account type |
| `extra_agents(address)` | Approved agents |
| `portfolio(address)` | Portfolio performance |
| `user_twap_slice_fills(address)` | TWAP slice fills |
| `user_vault_equities(address)` | Vault equity positions |
| `sub_accounts(address)` | Sub-accounts |

#### Orders

| Method | Description |
|--------|-------------|
| `order_status(address, oid)` | Order status by OID or CLOID |
| `historical_orders(address)` | Historical orders (up to 2000) |

#### Funding

| Method | Description |
|--------|-------------|
| `funding_history(coin, start_time:, end_time:)` | Funding rate history |
| `predicted_fundings` | Predicted funding rates |

#### Staking

| Method | Description |
|--------|-------------|
| `user_staking_summary(address)` | Staking summary |
| `user_staking_delegations(address)` | Delegations per validator |
| `user_staking_rewards(address)` | Historic rewards |
| `delegator_history(address)` | Full delegator history |

#### Other

| Method | Description |
|--------|-------------|
| `referral(address)` | Referral state |
| `query_user_to_multi_sig_signers(address)` | Multi-sig signers |
| `query_perp_deploy_auction_status` | Perp deploy auction status |
| `query_spot_deploy_auction_status(address)` | Spot deploy state |
| `query_user_dex_abstraction_state(address)` | Dex abstraction state |
| `query_user_abstraction_state(address)` | User abstraction state |

#### Asset Mapping

| Method | Description |
|--------|-------------|
| `name_to_asset(name)` | Map coin name to asset index |
| `coin_to_asset(coin)` | Map perp coin to asset index |
| `spot_coin_to_asset(coin)` | Map spot coin to asset index |
| `asset_to_sz_decimals(asset)` | Size decimals for an asset |
| `name_to_coin(name)` | Display name to wire coin name |
| `refresh_coin_mappings!` | Clear cached mappings |

#### WebSocket

| Method | Description |
|--------|-------------|
| `subscribe(subscription, callback)` | Subscribe to a channel, returns subscription_id |
| `unsubscribe(subscription, subscription_id)` | Unsubscribe from a channel |
| `disconnect_websocket` | Close WebSocket and stop ping thread |

### `Hyperliquid::Exchange`

Write API — requires private key.

```ruby
exchange = Hyperliquid::Exchange.new(
  private_key: "0x...",
  base_url: Hyperliquid::MAINNET_URL,
  vault_address: nil,         # default vault for all operations
  account_address: nil,       # for agent trading
  skip_ws: false
)
```

#### Orders

| Method | Description |
|--------|-------------|
| `order(coin, is_buy:, sz:, limit_px:, order_type:, ...)` | Place single order |
| `bulk_orders(orders, grouping:, builder:)` | Place multiple orders |
| `market_open(coin, is_buy:, sz:, px:, slippage:, ...)` | Market buy/sell (IOC + slippage) |
| `market_close(coin, sz:, px:, slippage:, ...)` | Close position at market |
| `modify_order(oid, coin:, is_buy:, sz:, limit_px:, order_type:, ...)` | Modify an order |
| `bulk_modify_orders(modifications)` | Modify multiple orders |
| `cancel(coin, oid)` | Cancel by order ID |
| `cancel_by_cloid(coin, cloid)` | Cancel by client order ID |
| `bulk_cancel(cancels)` | Cancel multiple by order ID |
| `bulk_cancel_by_cloid(cancels)` | Cancel multiple by client order ID |
| `schedule_cancel(time:)` | Dead man's switch cancel-all |

#### TWAP

| Method | Description |
|--------|-------------|
| `twap_order(coin, is_buy:, sz:, minutes:, ...)` | Place TWAP order |
| `twap_cancel(coin, twap_id:)` | Cancel TWAP order |

#### Account

| Method | Description |
|--------|-------------|
| `update_leverage(coin, leverage:, is_cross:)` | Set leverage |
| `update_isolated_margin(coin, is_buy:, amount:)` | Adjust isolated margin |
| `set_referrer(code)` | Set referral code |
| `set_expires_after(timestamp)` | Set action expiration |
| `approve_agent(name:)` | Approve agent, returns `[result, agent_key]` |
| `approve_builder_fee(builder:, max_fee_rate:)` | Approve builder fee |

#### Transfers

| Method | Description |
|--------|-------------|
| `usd_transfer(destination, amount:)` | Transfer USD |
| `spot_transfer(destination, token:, amount:)` | Transfer spot tokens |
| `withdraw_from_bridge(destination, amount:)` | Withdraw USDC to L1 |
| `usd_class_transfer(amount:, to_perp:)` | Move between perp and spot |
| `send_asset(destination, source_dex:, destination_dex:, token:, amount:)` | Cross-dex asset transfer |

#### Sub-accounts

| Method | Description |
|--------|-------------|
| `create_sub_account(name:)` | Create sub-account |
| `sub_account_transfer(sub_account_user:, is_deposit:, usd:)` | Sub-account USD transfer |
| `sub_account_spot_transfer(sub_account_user:, is_deposit:, token:, amount:)` | Sub-account spot transfer |

#### Vault

| Method | Description |
|--------|-------------|
| `vault_usd_transfer(vault_address:, is_deposit:, usd:)` | Vault USD deposit/withdraw |

#### Staking

| Method | Description |
|--------|-------------|
| `token_delegate(validator:, wei:, is_undelegate:)` | Delegate/undelegate tokens |

#### Multi-sig

| Method | Description |
|--------|-------------|
| `convert_to_multi_sig_user(authorized_users:, threshold:)` | Convert to multi-sig |
| `multi_sig(multi_sig_user, inner_action, signatures, nonce, ...)` | Execute multi-sig action |

#### Spot Deploy

| Method | Description |
|--------|-------------|
| `spot_deploy_register_token(token_name:, sz_decimals:, wei_decimals:, max_gas:, full_name:)` | Register token |
| `spot_deploy_user_genesis(token:, user_and_wei:, existing_token_and_wei:)` | User genesis |
| `spot_deploy_genesis(token, max_supply:, no_hyperliquidity:)` | Run genesis |
| `spot_deploy_register_spot(base_token:, quote_token:)` | Register trading pair |
| `spot_deploy_register_hyperliquidity(spot, start_px:, order_sz:, n_orders:, ...)` | Register liquidity |
| `spot_deploy_enable_freeze_privilege(token)` | Enable freeze |
| `spot_deploy_freeze_user(token, user:, freeze:)` | Freeze/unfreeze user |
| `spot_deploy_revoke_freeze_privilege(token)` | Revoke freeze |
| `spot_deploy_enable_quote_token(token)` | Enable quote token |
| `spot_deploy_set_deployer_trading_fee_share(token, share:)` | Set fee share |

#### Perp Deploy

| Method | Description |
|--------|-------------|
| `perp_deploy_register_asset(dex:, coin:, sz_decimals:, oracle_px:, ...)` | Register perp asset |
| `perp_deploy_set_oracle(dex:, oracle_pxs:, all_mark_pxs:, external_perp_pxs:)` | Set oracle prices |

#### Validator

| Method | Description |
|--------|-------------|
| `c_validator_register(node_ip:, name:, ...)` | Register validator |
| `c_validator_change_profile(unjailed:, ...)` | Update validator profile |
| `c_validator_unregister` | Unregister validator |
| `c_signer_unjail_self` | Unjail c-signer |
| `c_signer_jail_self` | Jail c-signer |

#### Other

| Method | Description |
|--------|-------------|
| `use_big_blocks(enable)` | Enable/disable big blocks |
| `agent_enable_dex_abstraction` | Enable dex abstraction for agent |
| `agent_set_abstraction(abstraction)` | Set agent abstraction level |
| `user_dex_abstraction(user, enabled:)` | Set user dex abstraction |
| `user_set_abstraction(user, abstraction:)` | Set user abstraction level |
| `noop(nonce)` | No-op (test signing) |

### Order Types

```ruby
# Good Till Cancel
{ limit: { "tif" => "Gtc" } }

# Immediate or Cancel
{ limit: { "tif" => "Ioc" } }

# Add Liquidity Only (Post Only)
{ limit: { "tif" => "Alo" } }

# Stop Loss
{ trigger: { triggerPx: 1700.0, isMarket: true, tpsl: "sl" } }

# Take Profit
{ trigger: { triggerPx: 2000.0, isMarket: true, tpsl: "tp" } }
```

### Client Order IDs

```ruby
cloid = Hyperliquid::Cloid.from_int(42)
# or
cloid = Hyperliquid::Cloid.from_str("0x0000000000000000000000000000002a")

exchange.order("ETH",
  is_buy: true, sz: 1.0, limit_px: 1800.0,
  order_type: { limit: { "tif" => "Gtc" } },
  cloid: cloid
)

exchange.cancel_by_cloid("ETH", cloid)
```

### Builder Orders

```ruby
exchange.order("ETH",
  is_buy: true, sz: 1.0, limit_px: 1800.0,
  order_type: { limit: { "tif" => "Gtc" } },
  builder: { "b" => "0xbuilder...", "f" => 10 }
)
```

## Architecture

```
lib/hyperliquid/
├── version.rb              # VERSION constant
├── constants.rb            # URLs, EIP-712 domains, user-signed types
├── error.rb                # Error hierarchy
├── utils.rb                # float_to_wire, order wire conversion
├── cloid.rb                # Client order ID value object
├── transport.rb            # Faraday HTTP client for /info and /exchange
├── signer.rb               # EIP-712 signing (L1 phantom agent + user-signed)
├── websocket_manager.rb    # WebSocket connection and subscription management
├── info.rb                 # Read API (44 methods + WebSocket)
└── exchange.rb             # Write API (54 methods)
```

### Signing

Two signing schemes, matching the official Python SDK exactly:

**L1 Actions** (orders, cancels, leverage — most trading operations):
msgpack(action) + nonce + vault flag → keccak256 → phantom agent → EIP-712 sign with `{chainId: 1337, name: "Exchange"}`

**User-Signed Actions** (transfers, withdrawals, staking — 11 action types):
EIP-712 sign with `{chainId: 0x66eee, name: "HyperliquidSignTransaction"}` and per-type field definitions

## Development

```bash
bundle install
rake test          # 314 tests, 636 assertions
bundle exec rubocop  # Lint
```

### Cross-Library Test Vectors

The test suite includes 141 test vectors generated by the official Python SDK (`hyperliquid-python-sdk` v0.22.0) to verify byte-identical output for:

- Float conversions (`float_to_wire`, `float_to_int_for_hashing`, `float_to_usd_int`)
- Order wire format and order type conversion
- Action hashing (all action types, with/without vault and expiration)
- L1 signatures (r, s, v for every action type on mainnet + testnet)
- User-signed signatures (r, s, v for all 11 types on mainnet + testnet)
- Phantom agent construction
- Order action assembly

To regenerate vectors:

```bash
pip3 install hyperliquid-python-sdk
python3 test/generate_test_vectors.py
```

## License

MIT
