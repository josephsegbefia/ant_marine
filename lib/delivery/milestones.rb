# frozen_string_literal: true

module Delivery
  module Milestones
    class Error < StandardError; end
    class Denied < Error; end

    module_function

    def complete!(actor:, milestone:)
      raise Denied, "You need permission to update milestones." unless manage?(actor, milestone.project)
      raise Error, "That milestone is already completed." if milestone.completed?
      raise Error, "Cancelled milestones cannot be completed." if milestone.status == "cancelled"
      if milestone.evidence_gated?
        raise Error, "Technical review and report release milestones need evidence from a later module (F4-07)."
      end

      milestone.update!(
        status: "completed",
        completed_at: Time.current,
        completed_by_membership: actor
      )
      AuditEvent.record!(
        organization: milestone.project.operating_organization,
        actor_membership: actor,
        event_type: "project.milestone.completed",
        subject: milestone.project,
        metadata: { "milestone_id" => milestone.id, "kind" => milestone.kind, "title" => milestone.title }
      )
      milestone
    end

    def manage?(actor, project)
      Delivery::Access.can_manage_delivery?(actor, project)
    end
  end
end
