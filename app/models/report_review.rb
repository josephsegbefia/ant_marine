# frozen_string_literal: true

class ReportReview < ApplicationRecord
  OUTCOMES = %w[approved changes_requested].freeze

  belongs_to :report_version
  belongs_to :reviewer_membership, class_name: "Membership"

  validates :outcome, inclusion: { in: OUTCOMES }
  validates :decided_at, presence: true

  def outcome_label
    outcome.tr("_", " ").humanize
  end
end
