# frozen_string_literal: true

class PaymentRecord < ApplicationRecord
  METHODS = Invoice::PAYMENT_METHODS

  belongs_to :invoice
  belongs_to :recorded_by_membership, class_name: "Membership"
  has_one :payment_reversal, dependent: :restrict_with_exception

  validates :amount_cents, numericality: { greater_than: 0, only_integer: true }
  validates :currency, inclusion: { in: Commercial::Money::MINOR_UNITS.keys }
  validates :payment_on, presence: true
  validates :payment_method, inclusion: { in: METHODS }
  validates :recorded_at, presence: true
  validate :currency_matches_invoice

  scope :recent_first, -> { order(recorded_at: :desc, id: :desc) }

  def reversed?
    payment_reversal.present?
  end

  def net_amount_cents
    return 0 if reversed?

    amount_cents
  end

  def payment_method_label
    payment_method.to_s.tr("_", " ").humanize
  end

  def display_amount
    Commercial::Money.display(amount_cents, currency)
  end

  private

    def currency_matches_invoice
      return if invoice.blank? || currency.blank?
      return if currency == invoice.currency

      errors.add(:currency, "must match the invoice currency")
    end
end
