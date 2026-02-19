#!/usr/bin/env python3
"""
Generate comprehensive test vectors from the official Hyperliquid Python SDK.
These vectors are used by the Ruby SDK's cross-library tests to verify
byte-for-byte compatibility.

Uses a deterministic private key so signatures are reproducible.
"""

import json
import sys
from eth_account import Account

from hyperliquid.utils.signing import (
    action_hash,
    construct_phantom_agent,
    float_to_int,
    float_to_int_for_hashing,
    float_to_usd_int,
    float_to_wire,
    get_timestamp_ms,
    order_request_to_order_wire,
    order_type_to_wire,
    order_wires_to_order_action,
    sign_l1_action,
    sign_usd_transfer_action,
    sign_spot_transfer_action,
    sign_withdraw_from_bridge_action,
    sign_usd_class_transfer_action,
    sign_send_asset_action,
    sign_agent,
    sign_approve_builder_fee,
    sign_token_delegate_action,
    sign_convert_to_multi_sig_user_action,
    sign_user_dex_abstraction_action,
    sign_user_set_abstraction_action,
)
from hyperliquid.utils.constants import MAINNET_API_URL

# Deterministic key for reproducible tests
PRIVATE_KEY = "0x0123456789012345678901234567890123456789012345678901234567890123"
wallet = Account.from_key(PRIVATE_KEY)

vectors = {}

# =============================================================================
# 1. FLOAT CONVERSION TESTS
# =============================================================================
float_to_wire_cases = [
    0, 1, 100, 1800.0, 1670.1, 0.0147, 1.23456789, 0.00000001,
    99999999.0, 0.1, 0.01, 0.001, 10.5, 100.00000001, 42.0, 1234.5678,
    0.00001234, 50.5, 200.0, 0.12345678
]
vectors["float_to_wire"] = []
for x in float_to_wire_cases:
    try:
        result = float_to_wire(x)
        vectors["float_to_wire"].append({"input": x, "output": result})
    except Exception as e:
        vectors["float_to_wire"].append({"input": x, "error": str(e)})

float_to_int_for_hashing_cases = [
    0, 1, 100, 1800.0, 1670.1, 0.0147, 0.00000001, 99999999.0,
    42.5, 1234.5678
]
vectors["float_to_int_for_hashing"] = []
for x in float_to_int_for_hashing_cases:
    try:
        result = float_to_int_for_hashing(x)
        vectors["float_to_int_for_hashing"].append({"input": x, "output": result})
    except Exception as e:
        vectors["float_to_int_for_hashing"].append({"input": x, "error": str(e)})

float_to_usd_int_cases = [0, 1, 100, 100.0, 50.5, 200.123456, 0.000001]
vectors["float_to_usd_int"] = []
for x in float_to_usd_int_cases:
    try:
        result = float_to_usd_int(x)
        vectors["float_to_usd_int"].append({"input": x, "output": result})
    except Exception as e:
        vectors["float_to_usd_int"].append({"input": x, "error": str(e)})

# =============================================================================
# 2. ORDER TYPE TO WIRE
# =============================================================================
order_type_wire_cases = [
    {"limit": {"tif": "Gtc"}},
    {"limit": {"tif": "Ioc"}},
    {"limit": {"tif": "Alo"}},
    {"trigger": {"triggerPx": 1700.0, "isMarket": True, "tpsl": "sl"}},
    {"trigger": {"triggerPx": 2000.0, "isMarket": True, "tpsl": "tp"}},
    {"trigger": {"triggerPx": 1500.5, "isMarket": False, "tpsl": "sl"}},
]
vectors["order_type_to_wire"] = []
for ot in order_type_wire_cases:
    result = order_type_to_wire(ot)
    vectors["order_type_to_wire"].append({"input": ot, "output": result})

# =============================================================================
# 3. ORDER REQUEST TO ORDER WIRE
# =============================================================================
from hyperliquid.utils.types import Cloid

order_wire_cases = [
    # Basic limit order
    {
        "order": {"coin": "ETH", "is_buy": True, "sz": 1.0, "limit_px": 1800.0,
                  "order_type": {"limit": {"tif": "Gtc"}}, "reduce_only": False},
        "asset": 1
    },
    # Sell order with IOC
    {
        "order": {"coin": "BTC", "is_buy": False, "sz": 0.5, "limit_px": 45000.0,
                  "order_type": {"limit": {"tif": "Ioc"}}, "reduce_only": True},
        "asset": 0
    },
    # With cloid
    {
        "order": {"coin": "ETH", "is_buy": True, "sz": 0.0147, "limit_px": 1670.1,
                  "order_type": {"limit": {"tif": "Gtc"}}, "reduce_only": False,
                  "cloid": Cloid.from_int(1)},
        "asset": 4
    },
    # Trigger order
    {
        "order": {"coin": "SOL", "is_buy": True, "sz": 100.0, "limit_px": 100.0,
                  "order_type": {"trigger": {"triggerPx": 103.0, "isMarket": True, "tpsl": "sl"}},
                  "reduce_only": False},
        "asset": 2
    },
    # High precision
    {
        "order": {"coin": "ETH", "is_buy": True, "sz": 0.12345678, "limit_px": 1234.5678,
                  "order_type": {"limit": {"tif": "Alo"}}, "reduce_only": False},
        "asset": 1
    },
]

vectors["order_request_to_order_wire"] = []
for case in order_wire_cases:
    wire = order_request_to_order_wire(case["order"], case["asset"])
    vectors["order_request_to_order_wire"].append({
        "asset": case["asset"],
        "is_buy": case["order"]["is_buy"],
        "sz": case["order"]["sz"],
        "limit_px": case["order"]["limit_px"],
        "order_type": case["order"]["order_type"],
        "reduce_only": case["order"]["reduce_only"],
        "cloid": case["order"].get("cloid", None),
        "output": wire
    })
# Fix cloid serialization
for v in vectors["order_request_to_order_wire"]:
    if v["cloid"] is not None:
        v["cloid"] = str(v["cloid"])

# =============================================================================
# 4. ACTION HASH TESTS
# =============================================================================
action_hash_cases = [
    # Dummy action, no vault
    {
        "action": {"type": "dummy", "num": 100000000000},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # Dummy with vault
    {
        "action": {"type": "dummy", "num": 100000000000},
        "vault_address": "0x1719884eb866cb12b2287399b15f7db5e7d775ea",
        "nonce": 0,
        "expires_after": None,
    },
    # Order action
    {
        "action": {"type": "order", "orders": [
            {"a": 1, "b": True, "p": "100", "s": "100", "r": False,
             "t": {"limit": {"tif": "Gtc"}}}
        ], "grouping": "na"},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # Order with cloid
    {
        "action": {"type": "order", "orders": [
            {"a": 1, "b": True, "p": "100", "s": "100", "r": False,
             "t": {"limit": {"tif": "Gtc"}},
             "c": "0x00000000000000000000000000000001"}
        ], "grouping": "na"},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # With specific nonce (phantom agent test)
    {
        "action": {"type": "order", "orders": [
            {"a": 4, "b": True, "p": "1670.1", "s": "0.0147", "r": False,
             "t": {"limit": {"tif": "Ioc"}}}
        ], "grouping": "na"},
        "vault_address": None,
        "nonce": 1677777606040,
        "expires_after": None,
    },
    # Cancel action
    {
        "action": {"type": "cancel", "cancels": [{"a": 1, "o": 123}]},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # TPSL trigger
    {
        "action": {"type": "order", "orders": [
            {"a": 1, "b": True, "p": "100", "s": "100", "r": False,
             "t": {"trigger": {"isMarket": True, "triggerPx": "103", "tpsl": "sl"}}}
        ], "grouping": "na"},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # createSubAccount
    {
        "action": {"type": "createSubAccount", "name": "example"},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # subAccountTransfer
    {
        "action": {"type": "subAccountTransfer",
                   "subAccountUser": "0x1d9470d4b963f552e6f671a81619d395877bf409",
                   "isDeposit": True, "usd": 10},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # scheduleCancel (no time)
    {
        "action": {"type": "scheduleCancel"},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # scheduleCancel (with time)
    {
        "action": {"type": "scheduleCancel", "time": 123456789},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # updateLeverage
    {
        "action": {"type": "updateLeverage", "asset": 1, "isCross": True, "leverage": 10},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # updateIsolatedMargin
    {
        "action": {"type": "updateIsolatedMargin", "asset": 1, "isBuy": True, "ntli": 100000000},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # setReferrer
    {
        "action": {"type": "setReferrer", "code": "MYCODE"},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # twapOrder
    {
        "action": {"type": "twapOrder", "twap": {"a": 1, "b": True, "s": "10", "r": False, "m": 30, "t": True}},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # twapCancel
    {
        "action": {"type": "twapCancel", "a": 1, "t": 42},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # batchModify
    {
        "action": {"type": "batchModify", "modifies": [
            {"oid": 456, "order": {"a": 1, "b": True, "p": "1850", "s": "2", "r": False,
                                   "t": {"limit": {"tif": "Gtc"}}}}
        ]},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # cancelByCloid
    {
        "action": {"type": "cancelByCloid", "cancels": [
            {"asset": 1, "cloid": "0x00000000000000000000000000000063"}
        ]},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # vaultTransfer
    {
        "action": {"type": "vaultTransfer", "vaultAddress": "0x1719884eb866cb12b2287399b15f7db5e7d775ea",
                   "isDeposit": True, "usd": 1000},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # evmUserModify (use_big_blocks)
    {
        "action": {"type": "evmUserModify", "usingBigBlocks": True},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # agentEnableDexAbstraction
    {
        "action": {"type": "agentEnableDexAbstraction"},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # agentSetAbstraction
    {
        "action": {"type": "agentSetAbstraction", "abstraction": "u"},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # noop
    {
        "action": {"type": "noop"},
        "vault_address": None,
        "nonce": 12345,
        "expires_after": None,
    },
    # With expires_after
    {
        "action": {"type": "dummy", "num": 100000000000},
        "vault_address": None,
        "nonce": 0,
        "expires_after": 9999999999999,
    },
    # With vault AND expires_after
    {
        "action": {"type": "dummy", "num": 100000000000},
        "vault_address": "0x1719884eb866cb12b2287399b15f7db5e7d775ea",
        "nonce": 0,
        "expires_after": 9999999999999,
    },
    # spotDeploy
    {
        "action": {"type": "spotDeploy",
                   "registerToken2": {"spec": {"name": "TEST", "szDecimals": 2, "weiDecimals": 18},
                                      "maxGas": 100, "fullName": "Test Token"}},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # CSignerAction
    {
        "action": {"type": "CSignerAction", "unjailSelf": None},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # CValidatorAction
    {
        "action": {"type": "CValidatorAction", "unregister": None},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
    # Order with builder
    {
        "action": {"type": "order", "orders": [
            {"a": 1, "b": True, "p": "1800", "s": "1", "r": False,
             "t": {"limit": {"tif": "Gtc"}}}
        ], "grouping": "na",
        "builder": {"b": "0x5e9ee1089755c3435139848e47e6635505d5a13a", "f": 10}},
        "vault_address": None,
        "nonce": 0,
        "expires_after": None,
    },
]

vectors["action_hash"] = []
for case in action_hash_cases:
    h = action_hash(case["action"], case["vault_address"], case["nonce"], case["expires_after"])
    vectors["action_hash"].append({
        "action": case["action"],
        "vault_address": case["vault_address"],
        "nonce": case["nonce"],
        "expires_after": case["expires_after"],
        "hash_hex": "0x" + h.hex()
    })

# =============================================================================
# 5. L1 ACTION SIGNING TESTS (full signature r, s, v)
# =============================================================================
l1_sign_cases = [
    # Mainnet
    {"action": {"type": "dummy", "num": 100000000000}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # Testnet
    {"action": {"type": "dummy", "num": 100000000000}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": False},
    # Mainnet with vault
    {"action": {"type": "dummy", "num": 100000000000},
     "vault": "0x1719884eb866cb12b2287399b15f7db5e7d775ea", "nonce": 0, "expires": None, "is_mainnet": True},
    # Testnet with vault
    {"action": {"type": "dummy", "num": 100000000000},
     "vault": "0x1719884eb866cb12b2287399b15f7db5e7d775ea", "nonce": 0, "expires": None, "is_mainnet": False},
    # Order mainnet
    {"action": {"type": "order", "orders": [
        {"a": 1, "b": True, "p": "100", "s": "100", "r": False, "t": {"limit": {"tif": "Gtc"}}}
    ], "grouping": "na"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # Order testnet
    {"action": {"type": "order", "orders": [
        {"a": 1, "b": True, "p": "100", "s": "100", "r": False, "t": {"limit": {"tif": "Gtc"}}}
    ], "grouping": "na"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": False},
    # Order with cloid mainnet
    {"action": {"type": "order", "orders": [
        {"a": 1, "b": True, "p": "100", "s": "100", "r": False, "t": {"limit": {"tif": "Gtc"}},
         "c": "0x00000000000000000000000000000001"}
    ], "grouping": "na"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # Order with cloid testnet
    {"action": {"type": "order", "orders": [
        {"a": 1, "b": True, "p": "100", "s": "100", "r": False, "t": {"limit": {"tif": "Gtc"}},
         "c": "0x00000000000000000000000000000001"}
    ], "grouping": "na"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": False},
    # TPSL trigger mainnet
    {"action": {"type": "order", "orders": [
        {"a": 1, "b": True, "p": "100", "s": "100", "r": False,
         "t": {"trigger": {"isMarket": True, "triggerPx": "103", "tpsl": "sl"}}}
    ], "grouping": "na"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # TPSL trigger testnet
    {"action": {"type": "order", "orders": [
        {"a": 1, "b": True, "p": "100", "s": "100", "r": False,
         "t": {"trigger": {"isMarket": True, "triggerPx": "103", "tpsl": "sl"}}}
    ], "grouping": "na"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": False},
    # createSubAccount mainnet
    {"action": {"type": "createSubAccount", "name": "example"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # createSubAccount testnet
    {"action": {"type": "createSubAccount", "name": "example"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": False},
    # subAccountTransfer mainnet
    {"action": {"type": "subAccountTransfer", "subAccountUser": "0x1d9470d4b963f552e6f671a81619d395877bf409",
                "isDeposit": True, "usd": 10}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # subAccountTransfer testnet
    {"action": {"type": "subAccountTransfer", "subAccountUser": "0x1d9470d4b963f552e6f671a81619d395877bf409",
                "isDeposit": True, "usd": 10}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": False},
    # scheduleCancel (no time) mainnet
    {"action": {"type": "scheduleCancel"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # scheduleCancel (no time) testnet
    {"action": {"type": "scheduleCancel"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": False},
    # scheduleCancel (with time) mainnet
    {"action": {"type": "scheduleCancel", "time": 123456789}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # scheduleCancel (with time) testnet
    {"action": {"type": "scheduleCancel", "time": 123456789}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": False},
    # cancel action
    {"action": {"type": "cancel", "cancels": [{"a": 1, "o": 123}]}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # cancelByCloid action
    {"action": {"type": "cancelByCloid", "cancels": [{"asset": 1, "cloid": "0x00000000000000000000000000000063"}]},
     "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # updateLeverage
    {"action": {"type": "updateLeverage", "asset": 1, "isCross": True, "leverage": 10},
     "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # updateIsolatedMargin
    {"action": {"type": "updateIsolatedMargin", "asset": 1, "isBuy": True, "ntli": 100000000},
     "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # setReferrer
    {"action": {"type": "setReferrer", "code": "MYCODE"},
     "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # twapOrder
    {"action": {"type": "twapOrder", "twap": {"a": 1, "b": True, "s": "10", "r": False, "m": 30, "t": True}},
     "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # batchModify
    {"action": {"type": "batchModify", "modifies": [
        {"oid": 456, "order": {"a": 1, "b": True, "p": "1850", "s": "2", "r": False, "t": {"limit": {"tif": "Gtc"}}}}
    ]}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # With expires_after (mainnet)
    {"action": {"type": "dummy", "num": 100000000000}, "vault": None, "nonce": 0, "expires": 9999999999999, "is_mainnet": True},
    # With vault + expires_after (mainnet)
    {"action": {"type": "dummy", "num": 100000000000},
     "vault": "0x1719884eb866cb12b2287399b15f7db5e7d775ea", "nonce": 0, "expires": 9999999999999, "is_mainnet": True},
    # vaultTransfer
    {"action": {"type": "vaultTransfer", "vaultAddress": "0x1719884eb866cb12b2287399b15f7db5e7d775ea",
                "isDeposit": True, "usd": 1000}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # evmUserModify
    {"action": {"type": "evmUserModify", "usingBigBlocks": True}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # spotDeploy
    {"action": {"type": "spotDeploy", "registerToken2": {
        "spec": {"name": "TEST", "szDecimals": 2, "weiDecimals": 18}, "maxGas": 100, "fullName": "Test Token"
    }}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # CSignerAction
    {"action": {"type": "CSignerAction", "unjailSelf": None}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # CValidatorAction
    {"action": {"type": "CValidatorAction", "unregister": None}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # noop
    {"action": {"type": "noop"}, "vault": None, "nonce": 12345, "expires": None, "is_mainnet": True},
    # agentEnableDexAbstraction
    {"action": {"type": "agentEnableDexAbstraction"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # agentSetAbstraction
    {"action": {"type": "agentSetAbstraction", "abstraction": "u"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # Order with builder
    {"action": {"type": "order", "orders": [
        {"a": 1, "b": True, "p": "1800", "s": "1", "r": False, "t": {"limit": {"tif": "Gtc"}}}
    ], "grouping": "na", "builder": {"b": "0x5e9ee1089755c3435139848e47e6635505d5a13a", "f": 10}},
     "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
    # Multiple orders
    {"action": {"type": "order", "orders": [
        {"a": 1, "b": True, "p": "1800", "s": "1", "r": False, "t": {"limit": {"tif": "Gtc"}}},
        {"a": 0, "b": False, "p": "45000", "s": "0.1", "r": False, "t": {"limit": {"tif": "Gtc"}}}
    ], "grouping": "na"}, "vault": None, "nonce": 0, "expires": None, "is_mainnet": True},
]

vectors["l1_signatures"] = []
for case in l1_sign_cases:
    sig = sign_l1_action(
        wallet, case["action"], case["vault"], case["nonce"],
        case["expires"], case["is_mainnet"]
    )
    vectors["l1_signatures"].append({
        "action": case["action"],
        "vault_address": case["vault"],
        "nonce": case["nonce"],
        "expires_after": case["expires"],
        "is_mainnet": case["is_mainnet"],
        "r": sig["r"],
        "s": sig["s"],
        "v": sig["v"],
    })

# =============================================================================
# 6. USER-SIGNED ACTION TESTS
# =============================================================================
user_signed_cases = []

# UsdSend
usd_send_action = {"destination": "0x5e9ee1089755c3435139848e47e6635505d5a13a",
                    "amount": "1", "time": 1687816341423, "type": "usdSend"}
for is_mainnet in [True, False]:
    sig = sign_usd_transfer_action(wallet, dict(usd_send_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "UsdSend",
        "action": dict(usd_send_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# SpotSend
spot_send_action = {"destination": "0x5e9ee1089755c3435139848e47e6635505d5a13a",
                     "amount": "50.5", "token": "USDC", "time": 1687816341423, "type": "spotSend"}
for is_mainnet in [True, False]:
    sig = sign_spot_transfer_action(wallet, dict(spot_send_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "SpotSend",
        "action": dict(spot_send_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# Withdraw
withdraw_action = {"destination": "0x5e9ee1089755c3435139848e47e6635505d5a13a",
                   "amount": "1", "time": 1687816341423, "type": "withdraw3"}
for is_mainnet in [True, False]:
    sig = sign_withdraw_from_bridge_action(wallet, dict(withdraw_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "Withdraw",
        "action": dict(withdraw_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# UsdClassTransfer
usd_class_action = {"amount": "200", "toPerp": True, "nonce": 1687816341423, "type": "usdClassTransfer"}
for is_mainnet in [True, False]:
    sig = sign_usd_class_transfer_action(wallet, dict(usd_class_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "UsdClassTransfer",
        "action": dict(usd_class_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# SendAsset
send_asset_action = {"destination": "0x5e9ee1089755c3435139848e47e6635505d5a13a",
                     "sourceDex": "dex1", "destinationDex": "dex2",
                     "token": "USDC", "amount": "100", "fromSubAccount": "",
                     "nonce": 1687816341423, "type": "sendAsset"}
for is_mainnet in [True, False]:
    sig = sign_send_asset_action(wallet, dict(send_asset_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "SendAsset",
        "action": dict(send_asset_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# ApproveAgent
approve_agent_action = {"type": "approveAgent",
                        "agentAddress": "0x5e9ee1089755c3435139848e47e6635505d5a13a",
                        "agentName": "mybot", "nonce": 1687816341423}
for is_mainnet in [True, False]:
    sig = sign_agent(wallet, dict(approve_agent_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "ApproveAgent",
        "action": dict(approve_agent_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# ApproveBuilderFee
approve_builder_action = {"maxFeeRate": "0.001",
                          "builder": "0x5e9ee1089755c3435139848e47e6635505d5a13a",
                          "nonce": 1687816341423, "type": "approveBuilderFee"}
for is_mainnet in [True, False]:
    sig = sign_approve_builder_fee(wallet, dict(approve_builder_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "ApproveBuilderFee",
        "action": dict(approve_builder_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# TokenDelegate
token_delegate_action = {"validator": "0x5e9ee1089755c3435139848e47e6635505d5a13a",
                         "wei": 1000000000000000000, "isUndelegate": False,
                         "nonce": 1687816341423, "type": "tokenDelegate"}
for is_mainnet in [True, False]:
    sig = sign_token_delegate_action(wallet, dict(token_delegate_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "TokenDelegate",
        "action": dict(token_delegate_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# ConvertToMultiSigUser
convert_multi_sig_action = {"type": "convertToMultiSigUser",
                            "signers": json.dumps({"authorizedUsers": ["0x1234567890123456789012345678901234567890",
                                                                       "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"],
                                                   "threshold": 2}),
                            "nonce": 1687816341423}
for is_mainnet in [True, False]:
    sig = sign_convert_to_multi_sig_user_action(wallet, dict(convert_multi_sig_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "ConvertToMultiSigUser",
        "action": dict(convert_multi_sig_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# UserDexAbstraction
user_dex_abs_action = {"type": "userDexAbstraction",
                       "user": "0x5e9ee1089755c3435139848e47e6635505d5a13a",
                       "enabled": True, "nonce": 1687816341423}
for is_mainnet in [True, False]:
    sig = sign_user_dex_abstraction_action(wallet, dict(user_dex_abs_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "UserDexAbstraction",
        "action": dict(user_dex_abs_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

# UserSetAbstraction
user_set_abs_action = {"type": "userSetAbstraction",
                       "user": "0x5e9ee1089755c3435139848e47e6635505d5a13a",
                       "abstraction": "unifiedAccount", "nonce": 1687816341423}
for is_mainnet in [True, False]:
    sig = sign_user_set_abstraction_action(wallet, dict(user_set_abs_action), is_mainnet)
    user_signed_cases.append({
        "primary_type": "UserSetAbstraction",
        "action": dict(user_set_abs_action),
        "is_mainnet": is_mainnet,
        "r": sig["r"], "s": sig["s"], "v": sig["v"],
    })

vectors["user_signed_signatures"] = user_signed_cases

# =============================================================================
# 7. PHANTOM AGENT CONSTRUCTION
# =============================================================================
phantom_cases = [
    {"hash_hex": "0x0fcbeda5ae3c4950a548021552a4fea2226858c4453571bf3f24ba017eac2908", "is_mainnet": True},
    {"hash_hex": "0x0fcbeda5ae3c4950a548021552a4fea2226858c4453571bf3f24ba017eac2908", "is_mainnet": False},
]
vectors["phantom_agent"] = []
for case in phantom_cases:
    h = bytes.fromhex(case["hash_hex"][2:])
    phantom = construct_phantom_agent(h, case["is_mainnet"])
    vectors["phantom_agent"].append({
        "hash_hex": case["hash_hex"],
        "is_mainnet": case["is_mainnet"],
        "source": phantom["source"],
        "connectionId": "0x" + phantom["connectionId"].hex() if isinstance(phantom["connectionId"], bytes) else str(phantom["connectionId"]),
    })

# =============================================================================
# 8. ORDER WIRES TO ORDER ACTION
# =============================================================================
order_action_cases = [
    {
        "wires": [{"a": 1, "b": True, "p": "1800", "s": "1", "r": False, "t": {"limit": {"tif": "Gtc"}}}],
        "builder": None,
        "grouping": "na",
    },
    {
        "wires": [
            {"a": 1, "b": True, "p": "1800", "s": "1", "r": False, "t": {"limit": {"tif": "Gtc"}}},
            {"a": 0, "b": False, "p": "45000", "s": "0.1", "r": False, "t": {"limit": {"tif": "Gtc"}}},
        ],
        "builder": None,
        "grouping": "na",
    },
    {
        "wires": [{"a": 1, "b": True, "p": "1800", "s": "1", "r": False, "t": {"limit": {"tif": "Gtc"}}}],
        "builder": {"b": "0x5e9ee1089755c3435139848e47e6635505d5a13a", "f": 10},
        "grouping": "na",
    },
]
vectors["order_wires_to_order_action"] = []
for case in order_action_cases:
    action = order_wires_to_order_action(case["wires"], case["builder"], case["grouping"])
    vectors["order_wires_to_order_action"].append({
        "wires": case["wires"],
        "builder": case["builder"],
        "grouping": case["grouping"],
        "output": action,
    })

# =============================================================================
# OUTPUT
# =============================================================================

# Summary
summary = {
    "float_to_wire": len(vectors["float_to_wire"]),
    "float_to_int_for_hashing": len(vectors["float_to_int_for_hashing"]),
    "float_to_usd_int": len(vectors["float_to_usd_int"]),
    "order_type_to_wire": len(vectors["order_type_to_wire"]),
    "order_request_to_order_wire": len(vectors["order_request_to_order_wire"]),
    "action_hash": len(vectors["action_hash"]),
    "l1_signatures": len(vectors["l1_signatures"]),
    "user_signed_signatures": len(vectors["user_signed_signatures"]),
    "phantom_agent": len(vectors["phantom_agent"]),
    "order_wires_to_order_action": len(vectors["order_wires_to_order_action"]),
}
vectors["_summary"] = summary

output_path = sys.argv[1] if len(sys.argv) > 1 else "test/fixtures/python_test_vectors.json"
import os
os.makedirs(os.path.dirname(output_path), exist_ok=True)

with open(output_path, "w") as f:
    json.dump(vectors, f, indent=2, default=str)

total = sum(summary.values())
print(f"Generated {total} test vectors across {len(summary)} categories:")
for k, v in summary.items():
    print(f"  {k}: {v}")
print(f"\nWritten to {output_path}")
