# frozen_string_literal: true

class Inspection < ApplicationRecord
  STATUSES = %w[
    draft assigned in_progress submitted corrections_requested completed cancelled
  ].freeze
  MODES = %w[simulated].freeze
  TERMINAL_STATUSES = %w[completed cancelled].freeze
  SUBMITTED_OR_LATER = %w[submitted corrections_requested completed].freeze

  belongs_to :operating_organization, class_name: "Organization"
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :project
  belongs_to :service, optional: true
  belongs_to :inspection_template_version
  belongs_to :schedule_event, optional: true
  belongs_to :assigned_surveyor_membership, class_name: "Membership", optional: true
  belongs_to :created_by_membership, class_name: "Membership"

  has_many :inspection_checklist_responses, dependent: :destroy
  has_many :inspection_findings, dependent: :destroy
  has_many :inspection_evidence_links, dependent: :destroy
  has_one :report, dependent: :nullify

  validates :reference_number, presence: true, uniqueness: true
  validates :title, presence: true, length: { maximum: 200 }
  validates :inspection_type, presence: true, length: { maximum: 100 }
  validates :status, inclusion: { in: STATUSES }
  validates :mode, inclusion: { in: MODES }
  validate :organization_ids_match_project
  validate :template_version_belongs_to_operating_org

  scope :for_project, ->(project) { where(project_id: project.id) }
  scope :simulated, -> { where(mode: "simulated") }

  def simulated?
    mode == "simulated"
  end

  def status_label
    status.tr("_", " ").humanize
  end

  def submitted_or_later?
    status.in?(SUBMITTED_OR_LATER)
  end

  def editable_checklist?
    status.in?(%w[draft assigned in_progress corrections_requested])
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

    def template_version_belongs_to_operating_org
      return if inspection_template_version.blank?

      template_org = inspection_template_version.inspection_template.operating_organization_id
      return if template_org == operating_organization_id

      errors.add(:inspection_template_version, "must belong to the operating organisation template catalogue")
    end
end
