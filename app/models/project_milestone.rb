# frozen_string_literal: true

class ProjectMilestone < ApplicationRecord
  STATUSES = %w[pending completed cancelled].freeze
  KINDS = %w[
    project_initiated planning mobilization site_work
    technical_review report_release project_completion operational
  ].freeze

  EVIDENCE_GATED = %w[technical_review report_release].freeze

  belongs_to :project
  belongs_to :responsible_membership, class_name: "Membership", optional: true
  belongs_to :completed_by_membership, class_name: "Membership", optional: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: KINDS }

  scope :eligible_for_progress, -> { where(counts_toward_progress: true).where.not(status: "cancelled") }

  def evidence_gated?
    kind.in?(EVIDENCE_GATED)
  end

  def completed?
    status == "completed"
  end
end
