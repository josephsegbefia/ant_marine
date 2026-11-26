# frozen_string_literal: true

module Inspections
  class AttachEvidence
    Result = Data.define(:link)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, inspection:, document_version:, finding: nil, checklist_item_key: nil)
      new(membership: membership).call(
        inspection: inspection,
        document_version: document_version,
        finding: finding,
        checklist_item_key: checklist_item_key
      )
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(inspection:, document_version:, finding:, checklist_item_key:)
      raise Denied, "You are not allowed to attach evidence to this inspection." unless Inspections::Access.can_edit_checklist?(@membership, inspection)
      raise InvalidState, "That file version does not belong to this project." unless document_version.document.project_id == inspection.project_id
      raise InvalidState, "Only security-checked files can be used as evidence." unless document_version.downloadable?
      raise Denied, "You are not allowed to use this file." unless Documents::Access.can_download_version?(@membership, document_version)

      if finding.present? && finding.inspection_id != inspection.id
        raise InvalidState, "That finding belongs to a different inspection."
      end

      if checklist_item_key.present? && Inspections::Checklist.item_for(inspection.inspection_template_version, checklist_item_key).blank?
        raise InvalidState, "That checklist item does not exist on this template."
      end

      link = nil
      Inspection.transaction do
        locked = Inspection.lock.find(inspection.id)
        raise InvalidState, "This inspection no longer accepts new evidence." unless locked.editable_checklist?

        link = locked.inspection_evidence_links.create!(
          document_version: document_version,
          finding: finding,
          checklist_item_key: checklist_item_key.to_s.presence,
          attached_by_membership: @membership,
          attached_at: Time.current
        )
        Inspections::Audit.evidence_attached(inspection: locked, link: link, actor_membership: @membership)
      end

      Result.new(link: link)
    end
  end
end
