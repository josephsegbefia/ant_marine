# frozen_string_literal: true

require "bigdecimal"

module Commercial
  # Converts staff-entered amounts ("1,250.00") to integer minor units and back.
  # Never uses floating point.
  module Money
    class ParseError < StandardError; end

    MINOR_UNITS = { "GHS" => 2, "USD" => 2, "EUR" => 2, "GBP" => 2 }.freeze
    MAX_MAJOR_AMOUNT = BigDecimal("999999999.99")
    AMOUNT_PATTERN = /\A\d{1,3}(,\d{3})*(\.\d+)?\z|\A\d+(\.\d+)?\z/

    module_function

    def supported?(currency)
      MINOR_UNITS.key?(currency.to_s)
    end

    def minor_units(currency)
      MINOR_UNITS.fetch(currency.to_s, 2)
    end

    def parse_minor(input, currency)
      text = input.to_s.strip.delete(" ")
      raise ParseError, "Enter a unit price, for example 1,250.00." if text.empty?
      raise ParseError, "Unit price cannot be negative." if text.start_with?("-")
      raise ParseError, "Enter the unit price as a number, for example 1,250.00." unless text.match?(AMOUNT_PATTERN)

      places = minor_units(currency)
      decimals = text.include?(".") ? text.split(".", 2).last.length : 0
      raise ParseError, "Use no more than #{places} decimal places for the unit price." if decimals > places

      amount = BigDecimal(text.delete(","))
      raise ParseError, "Unit price is too large. The maximum is #{display(max_minor(currency), currency)}." if amount > MAX_MAJOR_AMOUNT

      (amount * (10**places)).to_i
    end

    def max_minor(currency)
      (MAX_MAJOR_AMOUNT * (10**minor_units(currency))).to_i
    end

    def to_input(minor, currency)
      grouped_amount(minor.to_i, currency)
    end

    def display(minor, currency)
      value = minor.to_i
      sign = value.negative? ? "-" : ""
      "#{currency} #{sign}#{grouped_amount(value.abs, currency)}"
    end

    def grouped_amount(minor, currency)
      places = minor_units(currency)
      whole, fraction = minor.divmod(10**places)
      grouped = whole.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      places.zero? ? grouped : "#{grouped}.#{fraction.to_s.rjust(places, '0')}"
    end
  end
end
