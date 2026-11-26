# frozen_string_literal: true

class InspectionFinding < ApplicationRecord
  CLASSIFICATIONS = %w[observation deficiency recommendation other].freeze
  STATUSES = %w[draft recorded included_in_report].freeze

  belongs_to :inspection
  belongs_to :recorded_by_membership, class_name: "Membership"

  has_many :inspection_evidence_links, foreign_key: :finding_id, dependent: :nullify, inverse_of: :finding

  validates :reference_number, presence: true, length: { maximum: 50 }
  validates :reference_number, uniqueness: { scope: :inspection_id }
  validates :title, presence: true, length: { maximum: 200 }
  validates :observation, presence: true
  validates :classification, inclusion: { in: CLASSIFICATIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :recorded_at, presence: true

  def classification_label
    classification.humanize
  end

  def status_label
    status.tr("_", " ").humanize
  end
end
