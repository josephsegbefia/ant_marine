# frozen_string_literal: true

require "test_helper"

class Delivery::MilestonesAndTasksTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
    @surveyor = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: @surveyor, assignment_kind: "surveyor"
    )
  end

  test "operational milestone can be completed" do
    milestone = @project.project_milestones.find_by!(kind: "planning")
    Delivery::Milestones.complete!(actor: @staff, milestone: milestone)
    assert milestone.reload.completed?
    summary = @project.progress_summary
    assert_operator summary[:completed], :>=, 2
    assert_match(/of \d+ milestones complete/, summary[:label])
  end

  test "evidence-gated milestones cannot be completed" do
    milestone = @project.project_milestones.find_by!(kind: "technical_review")
    assert_raises(Delivery::Milestones::Error) do
      Delivery::Milestones.complete!(actor: @staff, milestone: milestone)
    end
    assert_equal "pending", milestone.reload.status
  end

  test "cancelled milestones are excluded from progress denominator" do
    operational = @project.project_milestones.create!(
      title: "Extra check", kind: "operational", status: "pending",
      position: 99, counts_toward_progress: true
    )
    operational.update!(status: "cancelled")
    summary = @project.progress_summary
    assert_equal @project.project_milestones.eligible_for_progress.count, summary[:total]
    assert_not_includes @project.project_milestones.eligible_for_progress.pluck(:id), operational.id
  end

  test "surveyor with delivery scope can create and complete tasks" do
    task = Delivery::Tasks.create!(
      actor: @surveyor, project: @project,
      attrs: { title: "Prep kit", assignee_membership_id: @surveyor.id, priority: "high" }
    )
    Delivery::Tasks.update!(actor: @surveyor, task: task, attrs: { status: "completed" })
    assert_equal "completed", task.reload.status
    assert task.completed_at.present?
  end

  test "reviewer cannot create tasks" do
    reviewer = create_staff_membership!(role_key: "staff.technical_reviewer")
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: reviewer,
      assignment_kind: "technical_reviewer"
    )
    assert_raises(Delivery::Tasks::Denied) do
      Delivery::Tasks.create!(actor: reviewer, project: @project, attrs: { title: "Secret task" })
    end
  end
end
