# frozen_string_literal: true

module Inspections
  class RecordFinding
    Result = Data.define(:finding)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, inspection:, title:, observation:, classification: "observation",
                  recommendation: nil, location_or_equipment: nil, checklist_item_key: nil)
      new(membership: membership).call(
        inspection: inspection,
        title: title,
        observation: observation,
        classification: classification,
        recommendation: recommendation,
        location_or_equipment: location_or_equipment,
        checklist_item_key: checklist_item_key
      )
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(inspection:, title:, observation:, classification:, recommendation:, location_or_equipment:, checklist_item_key:)
      raise Denied, "You are not allowed to record findings on this inspection." unless Inspections::Access.can_edit_checklist?(@membership, inspection)
      raise InvalidState, "Enter a finding title." if title.to_s.strip.blank?
      raise InvalidState, "Describe what was observed." if observation.to_s.strip.blank?
      raise InvalidState, "Choose a valid classification." unless InspectionFinding::CLASSIFICATIONS.include?(classification.to_s)

      if checklist_item_key.present? && Inspections::Checklist.item_for(inspection.inspection_template_version, checklist_item_key).blank?
        raise InvalidState, "That checklist item does not exist on this template."
      end

      finding = nil
      Inspection.transaction do
        locked = Inspection.lock.find(inspection.id)
        raise InvalidState, "This inspection no longer accepts new findings." unless locked.editable_checklist?

        reference_number = next_finding_ref(locked)
        finding = locked.inspection_findings.create!(
          reference_number: reference_number,
          title: title.to_s.strip,
          observation: observation.to_s.strip,
          recommendation: recommendation.to_s.strip.presence,
          location_or_equipment: location_or_equipment.to_s.strip.presence,
          classification: classification.to_s,
          status: "recorded",
          checklist_item_key: checklist_item_key.to_s.presence,
          recorded_by_membership: @membership,
          recorded_at: Time.current
        )
        Inspections::Audit.finding_recorded(inspection: locked, finding: finding, actor_membership: @membership)
      end

      Result.new(finding: finding)
    end

    private

      def next_finding_ref(inspection)
        numbers = inspection.inspection_findings.pluck(:reference_number).filter_map do |ref|
          ref[/\AF-(\d+)\z/, 1]&.to_i
        end
        format("F-%03d", (numbers.max || 0) + 1)
      end
  end
end
