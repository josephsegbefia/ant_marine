# frozen_string_literal: true

class Document < ApplicationRecord
  CLASSIFICATIONS = Storage::Asset::CLASSIFICATIONS
  VISIBILITY_INTENTS = %w[internal client_submitted for_client_release].freeze
  WORKFLOW_STATUSES = %w[
    working_draft submitted changes_requested approved released archived
  ].freeze

  CATEGORIES = {
    "vessel_records" => "Vessel records",
    "certificates" => "Certificates and class documents",
    "survey_photos" => "Survey photos",
    "field_notes" => "Field notes",
    "client_correspondence" => "Client correspondence",
    "technical_evidence" => "Technical evidence",
    "report_supporting" => "Report supporting material",
    "other" => "Other project file"
  }.freeze

  APPROVAL_REQUIRED_CATEGORIES = %w[technical_evidence report_supporting certificates].freeze

  belongs_to :operating_organization, class_name: "Organization"
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :project
  belongs_to :current_version, class_name: "DocumentVersion", optional: true
  belongs_to :upload_request, optional: true
  belongs_to :created_by_membership, class_name: "Membership"

  has_many :document_versions, dependent: :restrict_with_exception
  has_many :document_releases, dependent: :restrict_with_exception
  has_many :document_access_grants, dependent: :destroy

  validates :title, presence: true, length: { maximum: 200 }
  validates :category, presence: true, inclusion: { in: CATEGORIES.keys }
  validates :classification, inclusion: { in: CLASSIFICATIONS }
  validates :visibility_intent, inclusion: { in: VISIBILITY_INTENTS }
  validates :workflow_status, inclusion: { in: WORKFLOW_STATUSES }
  validate :organization_ids_match_project
  validate :confidential_classification_consistency

  scope :for_project, ->(project) { where(project_id: project.id) }
  scope :not_archived, -> { where(archived_at: nil) }

  def archived?
    archived_at.present?
  end

  def approval_required?
    APPROVAL_REQUIRED_CATEGORIES.include?(category)
  end

  def security_status
    current_version&.security_status || "no_version"
  end

  def downloadable?
    current_version&.downloadable? || false
  end

  def active_release
    document_releases.active.order(released_at: :desc).first
  end

  def active_release?
    active_release.present?
  end

  def category_label
    CATEGORIES.fetch(category, category.humanize)
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

    def confidential_classification_consistency
      return unless current_version&.storage_asset&.confidential?
      return if classification == "confidential"

      errors.add(:classification, "must be confidential when the stored file is confidential")
    end
end
