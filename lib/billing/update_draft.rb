# frozen_string_literal: true

module Billing
  class UpdateDraft
    Result = Data.define(:invoice)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, invoice:, attributes:, lines:)
      new(membership: membership).call(invoice: invoice, attributes: attributes, lines: lines)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(invoice:, attributes:, lines:)
      raise Denied, "Simulated invoicing is not available in production yet." unless CreateDraft.available?
      raise Denied, "You are not allowed to edit this invoice." unless Billing::Access.can_manage?(@membership, invoice)
      raise InvalidState, "Only draft invoices can be edited." unless invoice.draft?

      currency = invoice.currency
      normalized_lines = CreateDraft.new(membership: @membership).send(:normalize_lines, lines, currency)
      total = normalized_lines.sum { |line| line[:line_total_cents] }
      raise InvalidState, "Add at least one invoice item with a positive amount." unless total.positive?

      Invoice.transaction do
        locked = Invoice.lock.find(invoice.id)
        raise InvalidState, "Only draft invoices can be edited." unless locked.draft?

        project = Project.lock.find(locked.project_id)
        remaining = Billing::Capacity.remaining_billable_cents(project, excluding_invoice_id: locked.id, include_drafts: true)
        if total > remaining
          raise InvalidState,
                "This draft would over-commit the accepted commercial amount. Remaining including other drafts: #{Commercial::Money.display(remaining, currency)}."
        end

        locked.invoice_line_items.destroy_all
        normalized_lines.each_with_index do |line, index|
          locked.invoice_line_items.create!(line.merge(position: index + 1))
        end

        locked.update!(
          description: attributes[:description].to_s.strip.presence,
          issue_on: parse_date(attributes[:issue_on]) || locked.issue_on,
          due_on: parse_date(attributes[:due_on]),
          payment_terms_text: attributes[:payment_terms_text].to_s.strip.presence,
          total_cents: total
        )
        Billing::Audit.updated(invoice: locked, actor_membership: @membership)
        Result.new(invoice: locked.reload)
      end
    end

    private

      def parse_date(value)
        CreateDraft.new(membership: @membership).send(:parse_date, value)
      end
  end
end
