# frozen_string_literal: true

require "test_helper"

class Inspections::AccessTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
    @surveyor = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: @surveyor,
      assignment_kind: "surveyor", access_scope: "delivery"
    )
    @inspection = build_inspection!(project: @project, staff: @staff, assignee: @surveyor)
  end

  test "assigned surveyor can view inspection" do
    assert Inspections::Access.can_view?(@surveyor, @inspection)
  end

  test "unassigned surveyor cannot list or view project inspections" do
    stranger = create_staff_membership!(role_key: "staff.surveyor", email: "stranger-#{SecureRandom.hex(3)}@example.com")
    assert_not Inspections::Access.can_list_project_inspections?(stranger, @project)
    assert_not Inspections::Access.can_view?(stranger, @inspection)
  end

  test "ops manager can list project inspections" do
    assert Inspections::Access.can_list_project_inspections?(@staff, @project)
    assert Inspections::Access.can_view?(@staff, @inspection)
  end
end
