# frozen_string_literal: true

module Commercial
  class QuoteCalculator
    def self.recalculate!(revision)
      items = revision.line_items.reject(&:marked_for_destruction?)
      subtotal = items.sum do |item|
        qty = BigDecimal(item.quantity.to_s.presence || "1")
        (qty * item.unit_price_cents.to_i).round
      end
      revision.subtotal_cents = subtotal
      revision.total_cents = subtotal
    end
  end
end
