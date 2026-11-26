# frozen_string_literal: true

class DocumentReview < ApplicationRecord
  OUTCOMES = %w[approved changes_requested].freeze

  belongs_to :document_version
  belongs_to :reviewer_membership, class_name: "Membership"

  validates :outcome, inclusion: { in: OUTCOMES }, allow_nil: true
  validate :open_or_decided_consistency

  scope :open, -> { where(decided_at: nil) }
  scope :decided, -> { where.not(decided_at: nil) }

  def open?
    decided_at.nil?
  end

  private

    def open_or_decided_consistency
      if outcome.present? ^ decided_at.present?
        errors.add(:base, "Outcome and decided time must both be set or both be blank")
      end
    end
end
