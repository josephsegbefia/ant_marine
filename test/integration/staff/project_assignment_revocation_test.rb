# frozen_string_literal: true

require "test_helper"

class Staff::ProjectAssignmentRevocationTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @ops = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @ops)[:project]
    @surveyor = create_staff_membership!(role_key: "staff.surveyor", full_name: "Revoke Surveyor")
    @assignment = Delivery::Assign.call(
      actor_membership: @ops, project: @project, membership: @surveyor, assignment_kind: "surveyor"
    ).assignment
  end

  test "assigned surveyor can open project then is denied after removal" do
    sign_in_as @surveyor.user, membership: @surveyor
    get staff_project_path(@project)
    assert_response :success

    Delivery::Unassign.call(actor_membership: @ops, assignment: @assignment, reason: "Left team")

    get staff_project_path(@project)
    assert_response :not_found
  end

  test "removed surveyor cannot create tasks on former project" do
    Delivery::Unassign.call(actor_membership: @ops, assignment: @assignment, reason: "Left team")
    sign_in_as @surveyor.user, membership: @surveyor
    post staff_project_tasks_path(@project), params: { task: { title: "Should fail" } }
    assert_response :not_found
    assert_equal 0, @project.tasks.where(title: "Should fail").count
  end
end
