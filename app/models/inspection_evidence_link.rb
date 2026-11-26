# frozen_string_literal: true

class InspectionEvidenceLink < ApplicationRecord
  belongs_to :inspection
  belongs_to :document_version
  belongs_to :finding, class_name: "InspectionFinding", optional: true
  belongs_to :attached_by_membership, class_name: "Membership"

  validates :attached_at, presence: true
  validate :document_belongs_to_project
  validate :finding_belongs_to_inspection

  private

    def document_belongs_to_project
      return if document_version.blank? || inspection.blank?

      unless document_version.document.project_id == inspection.project_id
        errors.add(:document_version, "must belong to the same project as the inspection")
      end
    end

    def finding_belongs_to_inspection
      return if finding.blank? || inspection.blank?
      return if finding.inspection_id == inspection_id

      errors.add(:finding, "must belong to this inspection")
    end
end
