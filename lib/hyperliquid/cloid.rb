# frozen_string_literal: true

module Hyperliquid
  # Client Order ID: 128-bit hex string prefixed with "0x" (34 chars total).
  class Cloid
    attr_reader :raw

    def initialize(raw)
      unless raw.is_a?(String) && raw.match?(/\A0x[0-9a-f]{32}\z/)
        raise ArgumentError, "Cloid must be 0x + 32 hex chars, got: #{raw.inspect}"
      end

      @raw = raw
    end

    # Create from integer.
    def self.from_int(n)
      new(format("0x%032x", n))
    end

    # Create from hex string.
    def self.from_str(s)
      new(s.downcase)
    end

    # Return the raw hex string for wire format.
    def to_raw
      @raw
    end

    def ==(other)
      other.is_a?(Cloid) && @raw == other.raw
    end
    alias eql? ==

    def hash
      @raw.hash
    end

    def to_s
      @raw
    end

    def inspect
      "#<Hyperliquid::Cloid #{@raw}>"
    end
  end
end
