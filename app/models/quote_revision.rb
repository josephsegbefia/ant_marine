# frozen_string_literal: true

class QuoteRevision < ApplicationRecord
  REVISION_STATUSES = %w[draft pending_review approved issued superseded].freeze

  belongs_to :quote
  belongs_to :approved_by_membership, class_name: "Membership", optional: true
  belongs_to :issued_by_membership, class_name: "Membership", optional: true

  has_many :line_items, class_name: "QuoteLineItem", dependent: :destroy, inverse_of: :quote_revision

  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: :all_blank_line_item?

  validates :version_number, presence: true, uniqueness: { scope: :quote_id }
  validates :revision_status, inclusion: { in: REVISION_STATUSES }
  validates :currency, inclusion: { in: Quote::SUPPORTED_CURRENCIES }
  validate :prevent_mutation_when_frozen

  before_validation :assign_line_positions
  before_save :recalculate_totals!

  def mutable?
    frozen_at.blank?
  end

  def frozen?
    frozen_at.present?
  end

  def recipient_lines
    recipient_snapshot.presence || {}
  end

  private

    def all_blank_line_item?(attributes)
      attributes["description"].blank? && attributes["_destroy"] != "1"
    end

    def assign_line_positions
      line_items.reject(&:marked_for_destruction?).each_with_index do |item, index|
        item.position = index
      end
    end

    def recalculate_totals!
      Commercial::QuoteCalculator.recalculate!(self)
    end

    def prevent_mutation_when_frozen
      return unless persisted? && frozen_at_before_last_save.present?
      return unless changed? && (changed - %w[updated_at]).any?

      errors.add(:base, "This quotation version is fixed and cannot be changed.")
    end
end
