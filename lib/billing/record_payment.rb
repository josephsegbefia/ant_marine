# frozen_string_literal: true

module Billing
  class RecordPayment
    Result = Data.define(:invoice, :payment)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.available?
      CreateDraft.available?
    end

    def self.call(membership:, invoice:, attributes:)
      new(membership: membership).call(invoice: invoice, attributes: attributes)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(invoice:, attributes:)
      raise Denied, "Simulated payment recording is not available in production yet." unless self.class.available?
      raise Denied, "You are not allowed to record payments on this invoice." unless Billing::Access.can_record_payment?(@membership, invoice)

      attrs = attributes.to_h.with_indifferent_access
      currency = invoice.currency
      amount = parse_amount(attrs[:amount], attrs[:amount_cents], currency)
      method = attrs[:payment_method].to_s
      raise InvalidState, "Choose a recognised payment method." unless PaymentRecord::METHODS.include?(method)
      raise InvalidState, "Enter the payment date." if attrs[:payment_on].blank?

      payment = nil
      Invoice.transaction do
        locked = Invoice.lock.find(invoice.id)
        raise InvalidState, "Payments can only be recorded against issued invoices." unless locked.issued?
        raise InvalidState, "Payments cannot be recorded against void invoices." if locked.void?
        raise InvalidState, "Payment currency must match the invoice." if currency != locked.currency

        outstanding = locked.outstanding_cents
        if amount > outstanding
          raise InvalidState,
                "That payment exceeds the outstanding balance of #{Commercial::Money.display(outstanding, currency)}."
        end

        payment = locked.payment_records.create!(
          amount_cents: amount,
          currency: currency,
          payment_on: parse_date(attrs[:payment_on]),
          payment_method: method,
          external_reference: attrs[:external_reference].to_s.strip.presence,
          internal_note: attrs[:internal_note].to_s.strip.presence,
          recorded_by_membership: @membership,
          recorded_at: Time.current
        )

        audit = Billing::Audit.payment_recorded(invoice: locked, payment: payment, actor_membership: @membership)
        Notifications::StaffPublisher.payment_recorded(invoice: locked, audit_event: audit, actor: @membership)
      end

      Result.new(invoice: invoice.reload, payment: payment)
    end

    private

      def parse_amount(major, cents, currency)
        return cents.to_i if cents.present?

        Commercial::Money.parse_minor(major.to_s, currency)
      rescue Commercial::Money::ParseError => e
        raise InvalidState, e.message
      end

      def parse_date(value)
        return value if value.is_a?(Date)

        Date.iso8601(value.to_s)
      rescue ArgumentError
        raise InvalidState, "Enter the payment date as YYYY-MM-DD."
      end
  end
end
