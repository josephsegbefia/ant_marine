# frozen_string_literal: true

class QuoteLineItem < ApplicationRecord
  belongs_to :quote_revision, inverse_of: :line_items

  validates :description, presence: true, on: :editorial
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  before_validation :recalculate_line_total

  private

    def recalculate_line_total
      qty = BigDecimal(quantity.to_s.presence || "1")
      self.line_total_cents = (qty * unit_price_cents.to_i).round
    end
end
