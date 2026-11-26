# frozen_string_literal: true

class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :quote_line_item, optional: true

  validates :description, presence: true, length: { maximum: 500 }
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit, presence: true, length: { maximum: 40 }
  validates :unit_amount_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :line_total_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :position, numericality: { greater_than: 0, only_integer: true }

  def display_unit_amount
    Commercial::Money.display(unit_amount_cents, invoice.currency)
  end

  def display_line_total
    Commercial::Money.display(line_total_cents, invoice.currency)
  end
end
