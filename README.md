# Hyperliquid Ruby SDK

Ruby SDK for the [Hyperliquid](https://hyperliquid.xyz) DEX API. Supports trading, market data, EIP-712 signing, and account management.

## Installation

```ruby
gem "hyperliquid"
```

Or install directly:

```bash
gem install hyperliquid
```

### System Dependencies

The `eth` gem requires `libsecp256k1`. Install via:

```bash
# macOS
brew install secp256k1 automake libtool

# Ubuntu/Debian
apt-get install libsecp256k1-dev
```

## Quick Start

### Read-Only (no wallet needed)

```ruby
require "hyperliquid"

info = Hyperliquid::Info.new

# Market data
info.all_mids                    # => {"ETH" => "1800.5", "BTC" => "45000.0", ...}
info.meta                        # Perpetual market metadata
info.l2_snapshot("ETH")          # Order book

# User data
info.user_state("0x...")         # Positions and margin
info.open_orders("0x...")        # Open orders
info.user_fills("0x...")         # Trade history
```

### Trading (requires private key)

```ruby
exchange = Hyperliquid::Exchange.new(private_key: "0x...")

# Limit order
exchange.order("ETH",
  is_buy: true,
  sz: 1.0,
  limit_px: 1800.0,
  order_type: { limit: { "tif" => "Gtc" } }
)

# Market order (IOC with slippage)
exchange.market_open("ETH", is_buy: true, sz: 1.0, slippage: 0.05)

# Close position
exchange.market_close("ETH")

# Cancel orders
exchange.cancel([{ coin: "ETH", oid: 123 }])

# Modify order
exchange.modify_order(123,
  coin: "ETH", is_buy: true, sz: 2.0, limit_px: 1850.0,
  order_type: { limit: { "tif" => "Gtc" } }
)
```

### Testnet

```ruby
info = Hyperliquid::Info.new(base_url: Hyperliquid::TESTNET_URL)
exchange = Hyperliquid::Exchange.new(
  private_key: "0x...",
  base_url: Hyperliquid::TESTNET_URL
)
```

## API Reference

### `Hyperliquid::Info`

Read-only API. No private key required.

| Method | Description |
|--------|-------------|
| `meta` | Perpetual market metadata |
| `spot_meta` | Spot market metadata |
| `all_mids` | All mid prices |
| `l2_snapshot(coin, n_levels:)` | Order book snapshot |
| `candles_snapshot(coin, interval:, start_time:, end_time:)` | Candle data |
| `user_state(address)` | User perpetual state |
| `spot_user_state(address)` | User spot state |
| `open_orders(address)` | Open orders |
| `frontend_open_orders(address)` | Open orders with extra info |
| `user_fills(address)` | Trade history |
| `user_fills_by_time(address, start_time:, end_time:)` | Fills in time range |
| `user_fees(address)` | Fee rates |
| `order_status(address, oid)` | Order status |
| `funding_history(coin, start_time:, end_time:)` | Funding history |
| `predicted_fundings` | Predicted funding rates |
| `sub_accounts(address)` | Sub-accounts |
| `coin_to_asset(coin)` | Map coin name to asset index |

### `Hyperliquid::Exchange`

Write API. Requires private key.

| Method | Description |
|--------|-------------|
| `order(coin, is_buy:, sz:, limit_px:, order_type:, ...)` | Place single order |
| `bulk_orders(orders, grouping:)` | Place multiple orders |
| `market_open(coin, is_buy:, sz:, slippage:)` | Market buy/sell |
| `market_close(coin, slippage:)` | Close position at market |
| `modify_order(oid, coin:, ...)` | Modify an order |
| `bulk_modify_orders(modifications)` | Modify multiple orders |
| `cancel(cancels)` | Cancel by order ID |
| `cancel_by_cloid(cancels)` | Cancel by client order ID |
| `cancel_all(coin:)` | Cancel all open orders |
| `schedule_cancel(time:)` | Schedule cancel-all |
| `twap_order(coin, is_buy:, sz:, minutes:, ...)` | TWAP order |
| `update_leverage(coin, leverage:, is_cross:)` | Set leverage |
| `update_isolated_margin(coin, is_buy:, amount:)` | Adjust margin |
| `usd_transfer(destination, amount:)` | Transfer USD |
| `spot_transfer(destination, token:, amount:)` | Transfer spot tokens |
| `withdraw_from_bridge(destination, amount:)` | Withdraw to L1 |
| `usd_class_transfer(amount:, to_perp:)` | Move between perp/spot |
| `approve_agent(agent_address:, agent_name:)` | Approve trading agent |
| `create_sub_account(name:)` | Create sub-account |
| `sub_account_transfer(sub_account_user:, is_deposit:, usd:)` | Sub-account USD transfer |

### Order Types

```ruby
# Limit GTC (Good Till Cancel)
{ limit: { "tif" => "Gtc" } }

# Limit IOC (Immediate or Cancel)
{ limit: { "tif" => "Ioc" } }

# Limit ALO (Add Liquidity Only / Post Only)
{ limit: { "tif" => "Alo" } }

# Stop Loss (trigger)
{ trigger: { triggerPx: 1700.0, isMarket: true, tpsl: "sl" } }

# Take Profit (trigger)
{ trigger: { triggerPx: 2000.0, isMarket: true, tpsl: "tp" } }
```

### Client Order IDs

```ruby
cloid = Hyperliquid::Cloid.from_int(1)
cloid = Hyperliquid::Cloid.from_str("0x00000000000000000000000000000001")

exchange.order("ETH", is_buy: true, sz: 1.0, limit_px: 1800.0,
               order_type: { limit: { "tif" => "Gtc" } }, cloid: cloid)

exchange.cancel_by_cloid([{ coin: "ETH", cloid: cloid }])
```

### Vault Trading

```ruby
# Set default vault for all operations
exchange = Hyperliquid::Exchange.new(
  private_key: "0x...",
  vault_address: "0xvault..."
)

# Or per-operation
exchange.order("ETH", ..., vault_address: "0xvault...")
```

## Development

```bash
bundle install
rake test       # Run tests
rubocop         # Lint
```

## License

MIT
