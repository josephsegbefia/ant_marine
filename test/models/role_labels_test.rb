# frozen_string_literal: true

require "test_helper"

class RoleLabelsTest < ActiveSupport::TestCase
  test "staff role labels are human readable" do
    assert_equal "Operations Manager", RoleLabels.label("staff.operations_manager")
    assert_equal "General Staff", RoleLabels.label("staff.general_staff")
  end

  test "client role labels are human readable" do
    assert_equal "Organisation Owner", RoleLabels.label("client.org_owner")
  end

  test "invitation status labels" do
    assert_equal "Pending", RoleLabels.invitation_status("pending")
    assert_equal "Expired", RoleLabels.invitation_status("expired")
  end
end
