# frozen_string_literal: true

class UploadRequest < ApplicationRecord
  STATUSES = %w[
    requested submitted under_review changes_required satisfied cancelled
  ].freeze

  belongs_to :project
  belongs_to :operating_organization, class_name: "Organization"
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :requested_by_membership, class_name: "Membership"
  belongs_to :satisfied_document, class_name: "Document", optional: true

  has_many :documents, dependent: :nullify

  validates :title, presence: true, length: { maximum: 200 }
  validates :document_category, presence: true, inclusion: { in: Document::CATEGORIES.keys }
  validates :status, inclusion: { in: STATUSES }
  validate :organization_ids_match_project

  scope :open_for_client, -> { where(status: %w[requested changes_required]) }

  def open?
    status.in?(%w[requested changes_required])
  end

  def cancelled?
    status == "cancelled"
  end

  def satisfied?
    status == "satisfied"
  end

  private

    def organization_ids_match_project
      return if project.blank?

      if operating_organization_id != project.operating_organization_id
        errors.add(:operating_organization, "must match the project operating organisation")
      end
      if client_organization_id != project.client_organization_id
        errors.add(:client_organization, "must match the project client organisation")
      end
    end
end
