# frozen_string_literal: true

require "test_helper"

class Hyperliquid::UtilsTest < Minitest::Test
  def test_float_to_wire_integer
    assert_equal "100", Hyperliquid::Utils.float_to_wire(100)
  end

  def test_float_to_wire_decimal
    assert_equal "1670.1", Hyperliquid::Utils.float_to_wire(1670.1)
  end

  def test_float_to_wire_small_decimal
    assert_equal "0.0147", Hyperliquid::Utils.float_to_wire(0.0147)
  end

  def test_float_to_wire_whole_number_float
    assert_equal "103", Hyperliquid::Utils.float_to_wire(103.0)
  end

  def test_float_to_wire_zero
    assert_equal "0", Hyperliquid::Utils.float_to_wire(0)
  end

  def test_float_to_int_for_hashing_large
    assert_equal 12_312_312_312_300_000_000, Hyperliquid::Utils.float_to_int_for_hashing(123_123_123_123)
  end

  def test_float_to_int_for_hashing_small
    assert_equal 1231, Hyperliquid::Utils.float_to_int_for_hashing(0.00001231)
  end

  def test_float_to_int_for_hashing_decimal
    assert_equal 103_300_000, Hyperliquid::Utils.float_to_int_for_hashing(1.033)
  end

  def test_float_to_int_for_hashing_raises_on_precision_loss
    assert_raises(Hyperliquid::SigningError) do
      Hyperliquid::Utils.float_to_int_for_hashing(0.000012312312)
    end
  end

  def test_float_to_int_for_hashing_1000
    assert_equal 100_000_000_000, Hyperliquid::Utils.float_to_int_for_hashing(1000)
  end

  def test_order_request_to_order_wire_limit
    order = {
      is_buy: true,
      limit_px: 100,
      sz: 100,
      reduce_only: false,
      order_type: { limit: { "tif" => "Gtc" } }
    }
    wire = Hyperliquid::Utils.order_request_to_order_wire(order, 1)
    assert_equal 1, wire["a"]
    assert_equal true, wire["b"]
    assert_equal "100", wire["p"]
    assert_equal "100", wire["s"]
    assert_equal false, wire["r"]
    assert_equal({ "limit" => { "tif" => "Gtc" } }, wire["t"])
    refute wire.key?("c")
  end

  def test_order_request_to_order_wire_with_cloid
    cloid = Hyperliquid::Cloid.from_str("0x00000000000000000000000000000001")
    order = {
      is_buy: true,
      limit_px: 100,
      sz: 100,
      reduce_only: false,
      order_type: { limit: { "tif" => "Gtc" } },
      cloid: cloid
    }
    wire = Hyperliquid::Utils.order_request_to_order_wire(order, 1)
    assert_equal "0x00000000000000000000000000000001", wire["c"]
  end

  def test_order_request_to_order_wire_trigger
    order = {
      is_buy: true,
      limit_px: 100,
      sz: 100,
      reduce_only: false,
      order_type: { trigger: { triggerPx: 103, isMarket: true, tpsl: "sl" } }
    }
    wire = Hyperliquid::Utils.order_request_to_order_wire(order, 1)
    expected_trigger = { "isMarket" => true, "triggerPx" => "103", "tpsl" => "sl" }
    assert_equal({ "trigger" => expected_trigger }, wire["t"])
  end

  def test_address_to_bytes
    bytes = Hyperliquid::Utils.address_to_bytes("0x1719884eb866cb12b2287399b15f7db5e7d775ea")
    assert_equal 20, bytes.bytesize
    assert_equal "1719884eb866cb12b2287399b15f7db5e7d775ea", bytes.unpack1("H40")
  end
end
