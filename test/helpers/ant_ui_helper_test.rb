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

  test "flash_toast_payload adds invitation action for staff invitation notices" do
    flash[:notice] = "Invitation sent to colleague@example.com."

    action = flash_toast_payload.first
    assert_equal "View invitations", action[:action_label]
    assert_equal staff_invitations_path, action[:action_href]
  end
end
