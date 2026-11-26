# frozen_string_literal: true

require "test_helper"

class Reports::AccessTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
    @finance = create_staff_membership!(role_key: "staff.finance_officer")
    @report = build_report!(project: @project, staff: @staff)
  end

  test "ops manager can view report metadata" do
    assert Reports::Access.can_view_metadata?(@staff, @report)
  end

  test "unassigned finance officer cannot list project reports" do
    assert_not Reports::Access.can_list_project_reports?(@finance, @project)
    assert_not Reports::Access.can_view_metadata?(@finance, @report)
  end
end
