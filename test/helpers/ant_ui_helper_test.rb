# frozen_string_literal: true

require "test_helper"

class AntUiHelperTest < ActionView::TestCase
  include AntUiHelper
  include Rails.application.routes.url_helpers

  test "flash_toast_payload maps notice and alert types" do
    flash[:notice] = "Your account is ready."
    flash[:alert] = "Not allowed."

    payload = flash_toast_payload

    assert_equal 2, payload.size
    assert_equal "success", payload.find { |m| m[:message].include?("ready") }[:type]
    assert_equal "error", payload.find { |m| m[:message] == "Not allowed." }[:type]
    assert payload.any? { |m| m[:assertive] }
  end

  test "ant_back_link rejects unsafe external paths" do
    assert_raises(ArgumentError) { validate_back_path_for_test("https://evil.example/phish") }
    assert_raises(ArgumentError) { validate_back_path_for_test("//evil.example/phish") }
  end

  test "flash_toast_payload adds invitation action for staff invitation notices" do
    flash[:notice] = "Invitation sent to colleague@example.com."

    action = flash_toast_payload.first
    assert_equal "View invitations", action[:action_label]
    assert_equal staff_invitations_path, action[:action_href]
  end

  test "ant_select_tag renders a native select with data attributes for Stimulus targets" do
    html = ant_select_tag(
      "status",
      [ [ "New", "submitted" ], [ "Closed", "closed" ] ],
      label: "Status",
      selected: "submitted",
      include_blank: "All statuses",
      data: { quote_pricing_target: "currency", action: "change->quote-pricing#recalculate" }
    )

    assert_includes html, 'name="status"'
    assert_includes html, 'data-controller="custom-select"'
    assert_includes html, 'data-quote-pricing-target="currency"'
    assert_includes html, 'data-action="change-&gt;quote-pricing#recalculate"'
    assert_includes html, 'option selected="selected" value="submitted"'
    assert_includes html, ">All statuses<"
  end

  test "ant_date_field renders a native date input fallback with bounds" do
    html = ant_date_field(
      "from",
      label: "Received from",
      value: Date.new(2026, 11, 25),
      min: Date.new(2026, 1, 1),
      max: Date.new(2026, 11, 25),
      range_start_for: "to"
    )

    assert_includes html, 'type="date"'
    assert_includes html, 'name="from"'
    assert_includes html, 'value="2026-11-25"'
    assert_includes html, 'min="2026-01-01"'
    assert_includes html, 'max="2026-11-25"'
    assert_includes html, 'data-controller="ant-date-picker"'
    assert_includes html, 'data-ant-date-picker-range-start-for-value="to"'
    assert_includes html, "Wed 25 Nov 2026"
  end

  private

    def validate_back_path_for_test(path)
      send(:validate_back_path!, path)
    end
end
