# frozen_string_literal: true

module Billing
  class VoidInvoice
    Result = Data.define(:invoice)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.available?
      CreateDraft.available?
    end

    def self.call(membership:, invoice:, reason:, confirmation: false)
      new(membership: membership).call(invoice: invoice, reason: reason, confirmation: confirmation)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(invoice:, reason:, confirmation:)
      raise Denied, "Simulated invoice voiding is not available in production yet." unless self.class.available?
      raise Denied, "You are not allowed to void this invoice." unless Billing::Access.can_adjust?(@membership, invoice)
      raise Error, "Confirm that this issued invoice should be voided." unless ActiveModel::Type::Boolean.new.cast(confirmation)
      raise InvalidState, "Only issued invoices can be voided." unless invoice.issued?
      raise InvalidState, "Explain why this invoice is being voided." if reason.to_s.strip.blank?

      Invoice.transaction do
        locked = Invoice.lock.find(invoice.id)
        raise InvalidState, "Only issued invoices can be voided." unless locked.issued?

        if locked.net_paid_cents.positive?
          raise InvalidState, "Reverse all recorded payments before voiding this invoice."
        end

        if locked.released_to_client?
          raise InvalidState, "Revoke the client release before voiding this invoice."
        end

        locked.update!(
          issue_status: "void",
          voided_at: Time.current,
          voided_by_membership: @membership,
          void_reason: reason.to_s.strip
        )

        audit = Billing::Audit.voided(invoice: locked, actor_membership: @membership)
        Notifications::StaffPublisher.invoice_voided(invoice: locked, audit_event: audit, actor: @membership)
        Result.new(invoice: locked.reload)
      end
    end
  end
end
