# frozen_string_literal: true

require "test_helper"

class ProjectAccessScopeTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    pack = build_accepted_project!(staff: @staff)
    @project = pack[:project]
    @surveyor = create_staff_membership!(role_key: "staff.surveyor", full_name: "H1 Surveyor")
    @reviewer = create_staff_membership!(role_key: "staff.technical_reviewer", full_name: "H1 Reviewer")
    @collaborator = create_staff_membership!(role_key: "staff.general_staff", full_name: "H1 Collaborator")
    @finance = create_staff_membership!(role_key: "staff.finance_officer", full_name: "H1 Finance")
    @other_client = organizations(:other_client)
  end

  test "delivery surveyor can show and manage operational work" do
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: @surveyor,
      assignment_kind: "surveyor", access_scope: "delivery"
    )
    policy = ProjectPolicy.new(@surveyor, @project)
    assert policy.show?
    assert policy.manage?
    assert_not policy.assign?
    assert_not policy.transition?
    assert_not policy.view_commercial?
  end

  test "reviewer assignment cannot manage delivery" do
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: @reviewer,
      assignment_kind: "technical_reviewer", access_scope: "review"
    )
    policy = ProjectPolicy.new(@reviewer, @project)
    assert policy.show?
    assert_not policy.manage?
    assert_not policy.publish_update?
    assert_not policy.assign?
  end

  test "collaborator assignment cannot manage delivery" do
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: @collaborator,
      assignment_kind: "collaborator", access_scope: "collaborator"
    )
    policy = ProjectPolicy.new(@collaborator, @project)
    assert policy.show?
    assert_not policy.manage?
  end

  test "unassigned surveyor cannot show" do
    assert_not ProjectPolicy.new(@surveyor, @project).show?
  end

  test "finance without project permissions cannot show" do
    assert_not ProjectPolicy.new(@finance, @project).show?
  end

  test "client of other organization cannot show" do
    other_owner = Membership.create!(
      user: User.create!(
        email: "other-owner-#{SecureRandom.hex(3)}@example.com",
        password: "Secure-password-123",
        status: "active",
        full_name: "Other Owner"
      ),
      organization: @other_client,
      role_key: "client.org_owner",
      status: "active",
      permission_epoch: 0,
      lock_version: 0,
      accepted_at: Time.current
    )
    assert_not ProjectPolicy.new(other_owner, @project).show?
    scope = ProjectPolicy::Scope.new(other_owner, Project).resolve
    assert_not_includes scope, @project
  end

  test "assignment revocation removes show for view_assigned staff" do
    assignment = Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: @surveyor,
      assignment_kind: "surveyor"
    ).assignment
    assert ProjectPolicy.new(@surveyor, @project).show?
    Delivery::Unassign.call(actor_membership: @staff, assignment: assignment, reason: "Reassigned")
    assert_not ProjectPolicy.new(@surveyor, @project.reload).show?
    assert_not ProjectPolicy.new(@surveyor, @project).manage?
  end
end
