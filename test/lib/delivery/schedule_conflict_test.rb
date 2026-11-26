# frozen_string_literal: true

require "test_helper"

class Delivery::ScheduleConflictTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
    @surveyor = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: @surveyor, assignment_kind: "surveyor"
    )
    @starts = 2.days.from_now.change(hour: 9, min: 0)
    @ends = @starts + 2.hours
  end

  test "overlapping propose without override raises conflict" do
    Delivery::Schedule.propose!(
      actor: @staff, project: @project,
      attrs: { title: "Dive A", starts_at: @starts, ends_at: @ends, responsible_membership_id: @surveyor.id }
    )
    assert_raises(Delivery::Schedule::Conflict) do
      Delivery::Schedule.propose!(
        actor: @staff, project: @project,
        attrs: {
          title: "Dive B",
          starts_at: @starts + 30.minutes,
          ends_at: @ends + 30.minutes,
          responsible_membership_id: @surveyor.id
        }
      )
    end
  end

  test "conflict override with reason records override" do
    Delivery::Schedule.propose!(
      actor: @staff, project: @project,
      attrs: { title: "Dive A", starts_at: @starts, ends_at: @ends, responsible_membership_id: @surveyor.id }
    )
    event = Delivery::Schedule.propose!(
      actor: @staff, project: @project,
      attrs: {
        title: "Dive B",
        starts_at: @starts + 30.minutes,
        ends_at: @ends + 30.minutes,
        responsible_membership_id: @surveyor.id
      },
      conflict_override: true,
      conflict_reason: "Supervisor approved overlap"
    )
    assert event.conflict_override?
    assert_equal "Supervisor approved overlap", event.conflict_override_reason
  end

  test "reviewer cannot propose schedule" do
    reviewer = create_staff_membership!(role_key: "staff.technical_reviewer")
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: reviewer,
      assignment_kind: "technical_reviewer"
    )
    assert_raises(Delivery::Schedule::Denied) do
      Delivery::Schedule.propose!(
        actor: reviewer, project: @project,
        attrs: { title: "Review call", starts_at: @starts, ends_at: @ends, responsible_membership_id: reviewer.id }
      )
    end
  end
end
