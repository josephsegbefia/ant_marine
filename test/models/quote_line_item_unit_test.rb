# frozen_string_literal: true

require "test_helper"

class QuoteLineItemUnitTest < ActiveSupport::TestCase
  setup do
    @revision = create_draft_quote.current_revision
  end

  def build_item(**attrs)
    @revision.line_items.build({ description: "Work", quantity: "1", unit_price: "10.00" }.merge(attrs))
  end

  test "common units are stored as their simple value" do
    QuoteLineItem::COMMON_UNITS.each_key do |value|
      item = build_item(unit_choice: value, unit_other: "ignored")
      assert item.valid?, item.errors.full_messages.inspect
      assert_equal value, item.unit
    end
  end

  test "Other stores a tidy custom label" do
    item = build_item(unit_choice: "other", unit_other: "  cubic   metre ")
    assert item.valid?
    assert_equal "cubic metre", item.unit
    assert_equal "other", item.unit_choice
  end

  test "Other matching a common unit is stored as that unit" do
    item = build_item(unit_choice: "other", unit_other: "Day")
    assert item.valid?
    assert_equal "day", item.unit
  end

  test "custom units are validated" do
    { "" => /Choose a unit/, "other" => /instead of “Other”/, "<script>" => /Use letters/,
      "a" * 31 => /too long/i, "-dash first" => /Use letters/ }.each do |value, message|
      item = build_item(unit_choice: "other", unit_other: value)
      assert_not item.valid?, "#{value.inspect} should be refused"
      assert_match message, item.errors[:unit].join(" ")
    end
  end

  test "unknown choices are refused" do
    item = build_item(unit_choice: "fortnight")
    assert_not item.valid?
    assert_match(/Choose a unit/, item.errors[:unit].join)
  end

  test "units with symbols commonly used in marine work are accepted" do
    [ "m²", "per m³", "tonne/day", "lump sum (LS)", "100%" ].each do |value|
      item = build_item(unit_choice: "other", unit_other: value)
      assert item.valid?, "#{value} should be accepted: #{item.errors.full_messages}"
    end
  end

  test "existing free-text units are kept exactly and not re-validated when untouched" do
    item = build_item(unit: "each")
    item.save!
    item.update_columns(unit: "Per m^2 ")
    item = QuoteLineItem.find(item.id)

    assert_equal "other", item.unit_choice
    assert_equal "Per m^2 ", item.unit_other

    item.assign_attributes(unit_choice: "other", unit_other: "Per m^2", description: "Updated")
    assert item.save, item.errors.full_messages.inspect
    assert_equal "Per m^2 ", item.reload.unit
  end

  test "line totals are unaffected by the unit chosen" do
    item = build_item(quantity: "2.5", unit_price: "1,000.10", unit_choice: "other", unit_other: "hour block")
    item.valid?
    assert_equal 250_025, item.line_total_cents
  end
end
