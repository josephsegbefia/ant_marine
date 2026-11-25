# frozen_string_literal: true

class QuoteRevision < ApplicationRecord
  REVISION_STATUSES = %w[draft pending_review approved issued superseded].freeze
  FROZEN_MUTABLE_ATTRIBUTES = %w[revision_status issued_by_membership_id issued_at updated_at].freeze
  FROZEN_STATUS_CHANGES = [ %w[approved issued], %w[approved superseded], %w[issued superseded] ].freeze
  FROZEN_MESSAGE = "This quotation version is approved and can no longer be changed."
  MAX_LINE_ITEMS = 100

  belongs_to :quote
  belongs_to :approved_by_membership, class_name: "Membership", optional: true
  belongs_to :issued_by_membership, class_name: "Membership", optional: true

  has_many :line_items, -> { order(:position, :id) },
           class_name: "QuoteLineItem", dependent: :restrict_with_exception, inverse_of: :quote_revision

  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: :empty_new_line_item?

  validates :version_number, presence: true, uniqueness: { scope: :quote_id }
  validates :revision_status, inclusion: { in: REVISION_STATUSES }
  validates :currency, inclusion: { in: Quote::SUPPORTED_CURRENCIES, message: "Choose a supported currency." }
  validates :title, length: { maximum: 200 }
  validate :line_item_limit
  validate :prevent_mutation_when_frozen, on: :update

  before_validation :assign_line_positions
  before_save :recalculate_totals!
  before_destroy :prevent_destroy_when_frozen, prepend: true

  def mutable?
    frozen_at.blank? && frozen_at_in_database.blank?
  end

  def version_frozen?
    !mutable?
  end

  def recipient_lines
    recipient_snapshot.presence || {}
  end

  def active_line_items
    line_items.reject(&:marked_for_destruction?)
  end

  private

    def empty_new_line_item?(attributes)
      return false if attributes["id"].present?

      attributes["description"].blank? && attributes["unit_price"].blank? &&
        attributes["unit_price_cents"].blank? && attributes["quantity"].to_s.strip.in?([ "", "1" ])
    end

    def assign_line_positions
      return if version_frozen?

      active_line_items.sort_by.with_index { |item, index| [ item.position || 1_000_000, index ] }
                       .each_with_index { |item, index| item.position = index }
    end

    def recalculate_totals!
      return if frozen_at_in_database.present?

      Commercial::QuoteCalculator.recalculate!(self)
    end

    def line_item_limit
      errors.add(:base, "A quotation can have at most #{MAX_LINE_ITEMS} pricing lines.") if active_line_items.size > MAX_LINE_ITEMS
    end

    def prevent_mutation_when_frozen
      return if frozen_at_in_database.blank?

      disallowed = changed - FROZEN_MUTABLE_ATTRIBUTES
      status_change = revision_status_changed? && !FROZEN_STATUS_CHANGES.include?([ revision_status_in_database, revision_status ])
      line_changes = association(:line_items).loaded? &&
                     line_items.any? { |item| item.new_record? || item.changed? || item.marked_for_destruction? }

      errors.add(:base, FROZEN_MESSAGE) if disallowed.any? || status_change || line_changes
    end

    def prevent_destroy_when_frozen
      return if frozen_at_in_database.blank?

      errors.add(:base, FROZEN_MESSAGE)
      throw :abort
    end
end
