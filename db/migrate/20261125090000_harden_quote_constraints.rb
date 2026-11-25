# frozen_string_literal: true

class HardenQuoteConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :quotes,
                         "status IN ('draft', 'pending_review', 'returned_for_correction', 'approved_for_issuance', 'issued', 'withdrawn', 'superseded')",
                         name: "quotes_status_check"
    add_check_constraint :quotes,
                         "delivery_state IN ('not_prepared', 'prepared', 'delivery_pending', 'delivery_attempted', 'delivered', 'delivery_failed')",
                         name: "quotes_delivery_state_check"
    add_check_constraint :quote_revisions,
                         "revision_status IN ('draft', 'pending_review', 'approved', 'issued', 'superseded')",
                         name: "quote_revisions_status_check"
    add_check_constraint :quote_revisions,
                         "currency IN ('GHS', 'USD', 'EUR', 'GBP')",
                         name: "quote_revisions_currency_check"
    add_check_constraint :quote_revisions,
                         "subtotal_cents >= 0 AND total_cents >= 0",
                         name: "quote_revisions_totals_non_negative"
    add_check_constraint :quote_revisions,
                         "revision_status NOT IN ('approved', 'issued') OR frozen_at IS NOT NULL",
                         name: "quote_revisions_approved_are_frozen"
    add_check_constraint :quote_line_items,
                         "quantity > 0",
                         name: "quote_line_items_quantity_positive"
    add_check_constraint :quote_line_items,
                         "unit_price_cents >= 0 AND line_total_cents >= 0",
                         name: "quote_line_items_amounts_non_negative"
  end
end
