# frozen_string_literal: true

class Report < ApplicationRecord
  REPORT_KINDS = { "technical_report" => "Technical report" }.freeze
  MODES = %w[simulated].freeze

  belongs_to :operating_organization, class_name: "Organization"
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :project
  belongs_to :inspection, optional: true
  belongs_to :current_version, class_name: "ReportVersion", optional: true
  belongs_to :created_by_membership, class_name: "Membership"

  has_many :report_versions, dependent: :restrict_with_exception
  has_many :report_releases, dependent: :restrict_with_exception

  validates :reference_number, presence: true, uniqueness: true
  validates :title, presence: true, length: { maximum: 200 }
  validates :report_kind, inclusion: { in: REPORT_KINDS.keys }
  validates :mode, inclusion: { in: MODES }
  validate :organization_ids_match_project
  validate :inspection_belongs_to_project

  scope :for_project, ->(project) { where(project_id: project.id) }
  scope :simulated, -> { where(mode: "simulated") }

  def simulated?
    mode == "simulated"
  end

  def report_kind_label
    REPORT_KINDS.fetch(report_kind, report_kind.humanize)
  end

  def active_release
    report_releases.active.order(released_at: :desc).first
  end

  def released_to_client?
    active_release.present?
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

    def inspection_belongs_to_project
      return if inspection.blank? || project.blank?
      return if inspection.project_id == project_id

      errors.add(:inspection, "must belong to this project")
    end
end
