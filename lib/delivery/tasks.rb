# frozen_string_literal: true

module Delivery
  module Tasks
    class Error < StandardError; end
    class Denied < Error; end

    module_function

    def create!(actor:, project:, attrs:)
      assert_manage!(actor, project)
      task = project.tasks.create!(
        title: attrs.fetch(:title).to_s.strip,
        description: attrs[:description].to_s.strip.presence,
        assignee_membership_id: attrs[:assignee_membership_id].presence,
        priority: attrs[:priority].presence || "normal",
        status: "todo",
        due_on: attrs[:due_on].presence,
        notes: attrs[:notes].to_s.strip.presence,
        created_by_membership: actor
      )
      assert_assignee!(project, task.assignee_membership)
      audit_task!(actor, project, task, "project.task.created")
      notify_assignee!(actor, project, task) if task.assignee_membership_id.present?
      task
    end

    def update!(actor:, task:, attrs:)
      assert_manage_or_assignee!(actor, task)
      if attrs.key?(:assignee_membership_id)
        assert_manage!(actor, task.project)
        assert_assignee!(task.project, Membership.find_by(id: attrs[:assignee_membership_id]))
      end

      task.update!(attrs.slice(:title, :description, :priority, :due_on, :notes, :assignee_membership_id, :status).compact)
      if task.saved_change_to_status? && task.status == "completed"
        task.update!(completed_at: Time.current)
      elsif task.saved_change_to_status? && task.status != "completed"
        task.update!(completed_at: nil)
      end
      audit_task!(actor, task.project, task, "project.task.updated")
      task
    end

    def assert_manage!(actor, project)
      raise Denied, "You need permission to manage project tasks." unless Delivery::Access.can_manage_delivery?(actor, project)
    end

    def assert_manage_or_assignee!(actor, task)
      return if task.assignee_membership_id == actor.id && allowed?(actor, "assignments.participate")

      assert_manage!(actor, task.project)
    end

    def assert_assignee!(project, membership)
      return if membership.nil?
      raise Error, "Task assignees must be active project participants." unless membership.status == "active"
      raise Error, "Task assignees must belong to the project team." unless project.assigned?(membership.user) ||
        membership.id == project.coordinator_membership_id
    end

    def allowed?(actor, key)
      Authorization::EffectivePermissions.new(actor).allowed?(key)
    end

    def audit_task!(actor, project, task, event_type)
      AuditEvent.record!(
        organization: project.operating_organization,
        actor_membership: actor,
        event_type: event_type,
        subject: project,
        metadata: { "task_id" => task.id, "title" => task.title, "status" => task.status, "mode" => project.mode }
      )
    end

    def notify_assignee!(actor, project, task)
      return if task.assignee_membership_id == actor.id

      audit = AuditEvent.record!(
        organization: project.operating_organization,
        actor_membership: actor,
        event_type: "project.task.assigned",
        subject: project,
        metadata: { "task_id" => task.id, "assignee_membership_id" => task.assignee_membership_id }
      )
      Notifications::StaffPublisher.task_assigned(project: project, task: task, audit_event: audit)
    end
  end
end
