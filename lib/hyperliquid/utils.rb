# frozen_string_literal: true

require "bigdecimal"

module Hyperliquid
  module Utils
    module_function

    # Convert float to wire format string: 8 decimal precision, trailing zeros removed.
    # Examples: 100 -> "100", 1670.1 -> "1670.1", 0.0147 -> "0.0147"
    def float_to_wire(x)
      rounded = format("%.8f", x)
      raise SigningError, "float_to_wire causes rounding: #{x}" if (Float(rounded) - x).abs >= 1e-12

      rounded = "0" if rounded == "-0"
      # Normalize via BigDecimal to strip trailing zeros, format as fixed-point
      normalized = BigDecimal(rounded).to_s("F")
      # BigDecimal("100.00000000").to_s("F") => "100.0", we want "100"
      normalized.sub(/\.0$/, "")
    end

    # Convert float to integer by multiplying by 10^power, validating precision.
    def float_to_int(x, power)
      with_decimals = x * (10**power)
      rounded = with_decimals.round
      raise SigningError, "float_to_int causes rounding: #{x}" if (rounded - with_decimals).abs >= 1e-3

      rounded
    end

    # Convert float to int * 10^8 for action hashing.
    def float_to_int_for_hashing(x)
      float_to_int(x, 8)
    end

    # Convert USD float to int * 10^6.
    def float_to_usd_int(x)
      float_to_int(x, 6)
    end

    # Convert an OrderRequest hash to wire format for signing.
    def order_request_to_order_wire(order, asset)
      wire = {
        "a" => asset,
        "b" => order[:is_buy],
        "p" => float_to_wire(order[:limit_px]),
        "s" => float_to_wire(order[:sz]),
        "r" => order[:reduce_only],
        "t" => order_type_to_wire(order[:order_type])
      }
      wire["c"] = order[:cloid].to_raw if order[:cloid]
      wire
    end

    # Convert order type to wire format.
    def order_type_to_wire(order_type)
      if order_type[:limit]
        { "limit" => order_type[:limit] }
      elsif order_type[:trigger]
        t = order_type[:trigger]
        {
          "trigger" => {
            "isMarket" => t[:isMarket],
            "triggerPx" => float_to_wire(t[:triggerPx]),
            "tpsl" => t[:tpsl]
          }
        }
      else
        raise SigningError, "Unknown order type: #{order_type}"
      end
    end

    # Convert hex address string to 20-byte binary.
    def address_to_bytes(address)
      [address.delete_prefix("0x")].pack("H40")
    end
  end
end
