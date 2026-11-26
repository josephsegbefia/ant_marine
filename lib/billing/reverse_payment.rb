# frozen_string_literal: true

module Billing
  class ReversePayment
    Result = Data.define(:invoice, :payment, :reversal)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.available?
      CreateDraft.available?
    end

    def self.call(membership:, invoice:, payment:, reason:)
      new(membership: membership).call(invoice: invoice, payment: payment, reason: reason)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(invoice:, payment:, reason:)
      raise Denied, "Simulated payment reversals are not available in production yet." unless self.class.available?
      raise Denied, "You are not allowed to reverse payments on this invoice." unless Billing::Access.can_adjust?(@membership, invoice)
      raise InvalidState, "That payment does not belong to this invoice." unless payment.invoice_id == invoice.id
      raise InvalidState, "This payment has already been reversed." if payment.reversed?
      raise InvalidState, "Explain why this payment record is being corrected." if reason.to_s.strip.blank?

      reversal = nil
      Invoice.transaction do
        locked_invoice = Invoice.lock.find(invoice.id)
        locked_payment = PaymentRecord.lock.find(payment.id)
        raise InvalidState, "This payment has already been reversed." if locked_payment.reversed?

        reversal = PaymentReversal.create!(
          payment_record: locked_payment,
          amount_cents: locked_payment.amount_cents,
          reason: reason.to_s.strip,
          recorded_by_membership: @membership,
          recorded_at: Time.current
        )

        audit = Billing::Audit.payment_reversed(
          invoice: locked_invoice,
          payment: locked_payment,
          reversal: reversal,
          actor_membership: @membership
        )
        Notifications::StaffPublisher.payment_reversed(invoice: locked_invoice, audit_event: audit, actor: @membership)
      end

      Result.new(invoice: invoice.reload, payment: payment.reload, reversal: reversal)
    end
  end
end
