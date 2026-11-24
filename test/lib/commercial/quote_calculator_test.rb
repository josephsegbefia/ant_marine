# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteCalculatorTest < ActiveSupport::TestCase
  test "totals sum line items with decimal quantities" do
    revision = QuoteRevision.new
    revision.line_items.build(description: "Survey day", quantity: 2.5, unit_price_cents: 10_000)
    revision.line_items.build(description: "Travel", quantity: 1, unit_price_cents: 5_000)

    Commercial::QuoteCalculator.recalculate!(revision)

    assert_equal 30_000, revision.subtotal_cents
    assert_equal 30_000, revision.total_cents
  end
end
