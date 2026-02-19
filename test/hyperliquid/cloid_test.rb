# frozen_string_literal: true

require "test_helper"

class Hyperliquid::CloidTest < Minitest::Test
  def test_from_int
    cloid = Hyperliquid::Cloid.from_int(1)
    assert_equal "0x00000000000000000000000000000001", cloid.to_raw
  end

  def test_from_int_large
    cloid = Hyperliquid::Cloid.from_int(0xdeadbeef)
    assert_equal "0x000000000000000000000000deadbeef", cloid.to_raw
  end

  def test_from_str
    cloid = Hyperliquid::Cloid.from_str("0x00000000000000000000000000000001")
    assert_equal "0x00000000000000000000000000000001", cloid.to_raw
  end

  def test_from_str_downcases
    cloid = Hyperliquid::Cloid.from_str("0x000000000000000000000000DEADBEEF")
    assert_equal "0x000000000000000000000000deadbeef", cloid.to_raw
  end

  def test_invalid_too_short
    assert_raises(ArgumentError) { Hyperliquid::Cloid.new("0x1234") }
  end

  def test_invalid_no_prefix
    assert_raises(ArgumentError) { Hyperliquid::Cloid.new("00000000000000000000000000000001") }
  end

  def test_invalid_non_hex
    assert_raises(ArgumentError) { Hyperliquid::Cloid.new("0x0000000000000000000000000000gggg") }
  end

  def test_equality
    a = Hyperliquid::Cloid.from_int(42)
    b = Hyperliquid::Cloid.from_int(42)
    assert_equal a, b
  end

  def test_inequality
    a = Hyperliquid::Cloid.from_int(1)
    b = Hyperliquid::Cloid.from_int(2)
    refute_equal a, b
  end

  def test_to_s
    cloid = Hyperliquid::Cloid.from_int(1)
    assert_equal "0x00000000000000000000000000000001", cloid.to_s
  end
end
