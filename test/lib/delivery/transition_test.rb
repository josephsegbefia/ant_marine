# frozen_string_literal: true

require "test_helper"

class Delivery::TransitionTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
  end

  test "legitimate planning to scheduled" do
    Delivery::Transition.apply!(project: @project, action: :mark_scheduled, membership: @staff)
    assert_equal "scheduled", @project.reload.internal_status
    assert_equal "scheduled", @project.client_status
  end

  test "cancel requires reason" do
    assert_raises(Delivery::Transition::Error) do
      Delivery::Transition.apply!(project: @project, action: :cancel, membership: @staff, reason: "")
    end
    assert_equal "planning", @project.reload.internal_status
  end

  test "resume restores prior status after hold" do
    Delivery::Transition.apply!(project: @project, action: :mark_scheduled, membership: @staff)
    Delivery::Transition.apply!(project: @project, action: :start_work, membership: @staff)
    Delivery::Transition.apply!(project: @project, action: :place_on_hold, membership: @staff, reason: "Weather")
    assert_equal "on_hold", @project.reload.internal_status

    Delivery::Transition.apply!(project: @project, action: :resume, membership: @staff, reason: "Cleared")
    assert_equal "in_progress", @project.reload.internal_status
  end

  test "evidence-gated transitions are denied" do
    Delivery::Transition.apply!(project: @project, action: :mark_scheduled, membership: @staff)
    Delivery::Transition.apply!(project: @project, action: :start_work, membership: @staff)
    assert_raises(Delivery::Transition::InvalidState) do
      Delivery::Transition.apply!(project: @project, action: :enter_technical_review, membership: @staff)
    end
    assert_not_includes Delivery::Transition.available_actions(@project.reload), :enter_technical_review
  end

  test "surveyor without projects.manage cannot transition" do
    surveyor = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: surveyor, assignment_kind: "surveyor"
    )
    assert_raises(Delivery::Transition::Denied) do
      Delivery::Transition.apply!(project: @project, action: :mark_scheduled, membership: surveyor)
    end
  end

  test "cancel does not change commercial acceptance" do
    response = @project.quote_response
    Delivery::Transition.apply!(project: @project, action: :cancel, membership: @staff, reason: "Client deferred")
    assert_equal "cancelled", @project.reload.internal_status
    assert_equal "accepted", response.reload.response
  end
end
