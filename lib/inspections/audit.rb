# frozen_string_literal: true

module Inspections
  module Audit
    module_function

    def created(inspection:, actor_membership:)
      record(
        "inspections.created",
        organization: inspection.operating_organization,
        actor_membership: actor_membership,
        subject: inspection,
        metadata: base_meta(inspection)
      )
    end

    def checklist_saved(inspection:, response:, actor_membership:)
      record(
        "inspections.checklist_saved",
        organization: inspection.operating_organization,
        actor_membership: actor_membership,
        subject: inspection,
        metadata: base_meta(inspection).merge("item_key" => response.item_key)
      )
    end

    def finding_recorded(inspection:, finding:, actor_membership:)
      record(
        "inspections.finding_recorded",
        organization: inspection.operating_organization,
        actor_membership: actor_membership,
        subject: inspection,
        metadata: base_meta(inspection).merge("finding_id" => finding.id, "finding_ref" => finding.reference_number)
      )
    end

    def evidence_attached(inspection:, link:, actor_membership:)
      record(
        "inspections.evidence_attached",
        organization: inspection.operating_organization,
        actor_membership: actor_membership,
        subject: inspection,
        metadata: base_meta(inspection).merge(
          "document_version_id" => link.document_version_id,
          "finding_id" => link.finding_id,
          "checklist_item_key" => link.checklist_item_key
        )
      )
    end

    def submitted(inspection:, actor_membership:)
      record(
        "inspections.submitted",
        organization: inspection.operating_organization,
        actor_membership: actor_membership,
        subject: inspection,
        metadata: base_meta(inspection)
      )
    end

    def corrections_requested(inspection:, actor_membership:, comments: nil)
      record(
        "inspections.corrections_requested",
        organization: inspection.operating_organization,
        actor_membership: actor_membership,
        subject: inspection,
        metadata: base_meta(inspection).merge("comments" => comments.to_s.strip.presence)
      )
    end

    def completed(inspection:, actor_membership:)
      record(
        "inspections.completed",
        organization: inspection.operating_organization,
        actor_membership: actor_membership,
        subject: inspection,
        metadata: base_meta(inspection)
      )
    end

    def record(event_type, organization:, actor_membership:, subject:, metadata: {})
      AuditEvent.record!(
        event_type: event_type,
        organization: organization,
        actor_membership: actor_membership,
        subject: subject,
        metadata: metadata
      )
    end

    private :record

    def base_meta(inspection)
      {
        "inspection_id" => inspection.id,
        "reference_number" => inspection.reference_number,
        "project_id" => inspection.project_id,
        "status" => inspection.status
      }
    end
  end
end
