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
      if milestone.evidence_gated? && !evidence_satisfied?(milestone)
        label = milestone.kind.tr("_", " ")
        raise Error, "The #{label} milestone needs a submitted inspection or client report release before it can be marked complete."
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

    def evidence_satisfied?(milestone)
      project = milestone.project
      case milestone.kind
      when "technical_review"
        Delivery::TechnicalProgress.inspection_evidence_met?(project)
      when "report_release"
        Delivery::TechnicalProgress.report_release_evidence_met?(project)
      else
        true
      end
    end
  end
end
