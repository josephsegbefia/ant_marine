# frozen_string_literal: true

require "test_helper"

class Commercial::MoneyTest < ActiveSupport::TestCase
  test "parses ordinary amounts into integer minor units without floats" do
    assert_equal 125_000, Commercial::Money.parse_minor("1,250.00", "GHS")
    assert_equal 125_000, Commercial::Money.parse_minor("1250", "GHS")
    assert_equal 125_050, Commercial::Money.parse_minor("1250.5", "USD")
    assert_equal 1, Commercial::Money.parse_minor("0.01", "EUR")
    assert_equal 1_999_999, Commercial::Money.parse_minor("19999.99", "GBP")
    # 0.1 + 0.2 style float drift must not occur
    assert_equal 30, Commercial::Money.parse_minor("0.30", "GHS")
    assert_equal 99_999_999_999, Commercial::Money.parse_minor("999,999,999.99", "GHS")
  end

  test "rejects invalid, negative, over-precise and overflowing amounts" do
    {
      "abc" => /as a number/,
      "12.3.4" => /as a number/,
      "1e5" => /as a number/,
      "-5" => /cannot be negative/,
      "12.345" => /no more than 2 decimal places/,
      "1000000000" => /too large/,
      "1,25,0" => /as a number/,
      "" => /Enter a unit price/
    }.each do |input, message|
      error = assert_raises(Commercial::Money::ParseError, "expected #{input.inspect} to fail") do
        Commercial::Money.parse_minor(input, "GHS")
      end
      assert_match message, error.message
    end
  end

  test "formats minor units with grouping and currency" do
    assert_equal "GHS 1,250.00", Commercial::Money.display(125_000, "GHS")
    assert_equal "GHS 2,500.00", Commercial::Money.display(250_000, "GHS")
    assert_equal "USD 0.05", Commercial::Money.display(5, "USD")
    assert_equal "EUR 1,000,000.10", Commercial::Money.display(100_000_010, "EUR")
    assert_equal "1,250.00", Commercial::Money.to_input(125_000, "GHS")
    assert_equal "0.05", Commercial::Money.to_input(5, "USD")
  end

  test "form values read back to the same amount" do
    [ 0, 5, 125_000, 100_000_010 ].each do |minor|
      assert_equal minor, Commercial::Money.parse_minor(Commercial::Money.to_input(minor, "GHS"), "GHS")
    end
  end

  test "only supported currencies are recognised" do
    assert Commercial::Money.supported?("GHS")
    assert_not Commercial::Money.supported?("NGN")
  end
end
