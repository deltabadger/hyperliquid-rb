# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-06-17

### Fixed

- **Spot coin → asset mapping now uses the universe entry's permanent `index`
  field instead of its array position.** The live spot universe is sparse
  (delisted pairs leave permanent index gaps), so for every entry after the
  first gap, position no longer equals index. The old code addressed orders to
  the wrong spot asset — e.g. `name_to_asset("@107")` (HYPE/USDC) returned
  `10105` (HPYH/USDC) — which could be rejected or, for a similarly priced
  neighbor, silently fill the wrong coin. This matches the official Python SDK
  (`asset = spot_info["index"] + 10000`). Affects `Info#name_to_asset`,
  `Info#spot_coin_to_asset`, and every `Exchange` trading op that resolves a
  spot coin (orders, modify, cancel, TWAP, leverage/margin, slippage pricing).

### Added

- `Info#name_to_asset` now resolves the friendly `BASE/QUOTE` spot name (e.g.
  `"HYPE/USDC"`) in addition to the universe name (e.g. `"@107"`), mirroring the
  Python SDK's `name_to_coin` mapping.

### Changed (breaking)

- **`Info#asset_to_sz_decimals` spot keys moved from token index to asset id.**
  Spot `szDecimals` are now keyed by the order asset id (`10_000 + index`) and
  hold the base token's `szDecimals`, matching the Python SDK. Previously they
  were keyed by the raw token index, which returned `nil` for real asset ids and
  collided with perpetual asset ids. This also fixes spot `slippage_price`
  rounding (was falling back to `0` decimals) — the likely cause of latent
  "Order has invalid size" errors. Any caller that looked up spot `szDecimals`
  by a small token index must switch to the asset id.

[0.1.1]: https://github.com/deltabadger/hyperliquid-rb/releases/tag/v0.1.1
