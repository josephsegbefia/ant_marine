# frozen_string_literal: true

module Inspections
  class Submit
    Result = Data.define(:inspection)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, inspection:, confirmation: false)
      new(membership: membership).call(inspection: inspection, confirmation: confirmation)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(inspection:, confirmation:)
      raise Denied, "You are not allowed to submit this inspection." unless Inspections::Access.can_edit_checklist?(@membership, inspection)
      raise Error, "Confirm that this checklist is complete and ready to submit." unless ActiveModel::Type::Boolean.new.cast(confirmation)
      raise InvalidState, "This inspection cannot be submitted in its current state." unless inspection.status.in?(%w[draft assigned in_progress corrections_requested])

      version = inspection.inspection_template_version
      responses_by_key = inspection.inspection_checklist_responses.index_by(&:item_key)
      evidence_keys = inspection.inspection_evidence_links.where.not(checklist_item_key: nil).pluck(:checklist_item_key).uniq

      Inspections::Checklist.required_keys(version).each do |key|
        item = Inspections::Checklist.item_for(version, key)
        response = responses_by_key[key]
        raise InvalidState, "Complete required item: #{item['prompt']}" unless Inspections::Checklist.response_complete?(item, response)
      end

      Inspections::Checklist.evidence_required_keys(version).each do |key|
        item = Inspections::Checklist.item_for(version, key)
        unless evidence_keys.include?(key)
          raise InvalidState, "Attach evidence for: #{item['prompt']}"
        end
      end

      locked = nil
      Inspection.transaction do
        locked = Inspection.lock.find(inspection.id)
        raise InvalidState, "This inspection cannot be submitted in its current state." unless locked.status.in?(%w[draft assigned in_progress corrections_requested])

        locked.update!(status: "submitted", submitted_at: Time.current)
        audit = Inspections::Audit.submitted(inspection: locked, actor_membership: @membership)
        Notifications::StaffPublisher.inspection_submitted(inspection: locked, audit_event: audit, actor: @membership)
        Delivery::TechnicalProgress.sync!(project: locked.project)
      end

      Result.new(inspection: locked)
    end
  end
end
