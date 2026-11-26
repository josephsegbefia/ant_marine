# frozen_string_literal: true

module Delivery
  class Unassign
    class Error < StandardError; end
    class Denied < Error; end

    def self.call(actor_membership:, assignment:, reason:)
      new(actor_membership: actor_membership).call(assignment: assignment, reason: reason)
    end

    def initialize(actor_membership:)
      @actor = actor_membership
    end

    def call(assignment:, reason:)
      raise Denied, "You need permission to change project assignments." unless allowed?("projects.assign")
      raise Error, "Add a short reason for removing this assignment." if reason.to_s.strip.blank?
      raise Error, "That assignment is already inactive." unless assignment.active?

      Project.transaction do
        project = Project.lock.find(assignment.project_id)
        assignment.deactivate!
        if project.coordinator_membership_id == assignment.membership_id
          project.update!(coordinator_membership: nil)
        end

        audit = AuditEvent.record!(
          organization: project.operating_organization,
          actor_membership: @actor,
          event_type: "project.assignment.removed",
          subject: project,
          metadata: {
            "assignment_id" => assignment.id,
            "user_id" => assignment.user_id,
            "assignment_kind" => assignment.assignment_kind,
            "reason" => reason.to_s.strip,
            "mode" => project.mode
          }
        )

        Notifications::StaffPublisher.project_assignment_changed(
          project: project,
          previous: assignment.membership,
          actor: @actor,
          audit_event: audit
        )

        assignment
      end
    end

    private

      def allowed?(key)
        Authorization::EffectivePermissions.new(@actor).allowed?(key)
      end
  end
end
