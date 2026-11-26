# frozen_string_literal: true

module Delivery
  class Assign
    class Error < StandardError; end
    class Denied < Error; end

    Result = Data.define(:assignment)

    def self.call(actor_membership:, project:, membership:, assignment_kind:, reason: nil, access_scope: nil)
      new(actor_membership: actor_membership).call(
        project: project,
        membership: membership,
        assignment_kind: assignment_kind,
        reason: reason,
        access_scope: access_scope
      )
    end

    def initialize(actor_membership:)
      @actor = actor_membership
    end

    def call(project:, membership:, assignment_kind:, reason: nil, access_scope: nil)
      raise Denied, "You need permission to assign project team members." unless allowed?("projects.assign")
      raise Denied, "Only active ANT Marine staff can manage assignments." unless staff_actor?
      raise Error, "Choose a valid assignment role." unless assignment_kind.to_s.in?(Assignment::KINDS)

      target = membership
      raise Error, "Choose an active staff member." unless target&.status == "active" && target.staff_domain?
      raise Error, "That person belongs to a different organisation." unless target.organization_id == project.operating_organization_id
      raise Error, "Suspended accounts cannot be assigned." unless target.user.status == "active"

      scope = access_scope.presence || Assignment::KIND_DEFAULT_SCOPE.fetch(assignment_kind.to_s)
      raise Error, "Choose a valid access scope." unless scope.in?(Assignment::SCOPES)

      Project.transaction do
        locked = Project.lock.find(project.id)

        # One active coordinator at a time
        if assignment_kind.to_s == "coordinator"
          locked.active_assignments.where(assignment_kind: "coordinator").find_each do |row|
            row.deactivate!
          end
        end

        existing = locked.assignments.find_by(user_id: target.user_id, assignment_kind: assignment_kind, active: true)
        if existing
          existing.update!(access_scope: scope, reason: reason.to_s.strip.presence || existing.reason)
          assignment = existing
        else
          assignment = locked.assignments.create!(
            user: target.user,
            membership: target,
            assignment_kind: assignment_kind,
            access_scope: scope,
            active: true,
            assigned_by_membership: @actor,
            reason: reason.to_s.strip.presence
          )
        end

        locked.update!(coordinator_membership: target) if assignment_kind.to_s == "coordinator"

        audit = AuditEvent.record!(
          organization: locked.operating_organization,
          actor_membership: @actor,
          event_type: "project.assignment.created",
          subject: locked,
          metadata: {
            "assignment_id" => assignment.id,
            "user_id" => target.user_id,
            "assignment_kind" => assignment.assignment_kind,
            "access_scope" => assignment.access_scope,
            "mode" => locked.mode
          }
        )

        Notifications::StaffPublisher.project_assigned(
          project: locked,
          assignee: target,
          actor: @actor,
          audit_event: audit
        )

        Result.new(assignment: assignment)
      end
    end

    private

      def staff_actor?
        @actor&.status == "active" && @actor.staff_domain?
      end

      def allowed?(key)
        Authorization::EffectivePermissions.new(@actor).allowed?(key)
      end
  end
end
