# frozen_string_literal: true

class PaymentReversal < ApplicationRecord
  belongs_to :payment_record
  belongs_to :recorded_by_membership, class_name: "Membership"

  validates :amount_cents, numericality: { greater_than: 0, only_integer: true }
  validates :reason, presence: true, length: { maximum: 1000 }
  validates :recorded_at, presence: true
  validate :amount_matches_payment

  private

    def amount_matches_payment
      return if payment_record.blank? || amount_cents.blank?
      return if amount_cents == payment_record.amount_cents

      errors.add(:amount_cents, "must reverse the full recorded payment amount")
    end
end
