# frozen_string_literal: true

class InspectionChecklistResponse < ApplicationRecord
  belongs_to :inspection
  belongs_to :updated_by_membership, class_name: "Membership"

  validates :item_key, presence: true, length: { maximum: 100 }
  validates :response_type, presence: true
  validates :item_key, uniqueness: { scope: :inspection_id }
  validate :response_type_allowed
  validate :inspection_allows_edits, on: :update

  private

    def response_type_allowed
      return if response_type.blank?
      return if Inspections::TemplateSchema::RESPONSE_TYPES.include?(response_type)

      errors.add(:response_type, "is not a supported response type")
    end

    def inspection_allows_edits
      return if inspection.blank? || inspection.editable_checklist?

      errors.add(:inspection, "no longer accepts checklist changes")
    end
end
