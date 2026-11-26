# frozen_string_literal: true

module Billing
  class CreateDraft
    Result = Data.define(:invoice)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.available?
      !Rails.env.production?
    end

    def self.call(membership:, project:, attributes:, lines:, confirmation: false)
      new(membership: membership).call(project: project, attributes: attributes, lines: lines, confirmation: confirmation)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(project:, attributes:, lines:, confirmation:)
      raise Denied, "Simulated invoicing is not available in production yet." unless self.class.available?
      raise Denied, "You are not allowed to create invoices." unless Billing::Access.can_manage?(@membership)
      raise Error, "Confirm that this draft invoice should be created." unless ActiveModel::Type::Boolean.new.cast(confirmation)
      raise InvalidState, "Only simulated projects can receive development invoices." unless project.simulated?
      raise InvalidState, "Project commercial source is incomplete." if project.commercial_snapshot.blank?
      raise InvalidState, "Project must keep its accepted commercial response." unless project.quote_response&.accepted?

      currency = project.commercial_snapshot["currency"].to_s
      raise InvalidState, "Unsupported currency on the commercial source." unless Commercial::Money.supported?(currency)

      normalized_lines = normalize_lines(lines, currency)
      total = normalized_lines.sum { |line| line[:line_total_cents] }
      raise InvalidState, "Add at least one invoice item with a positive amount." unless total.positive?

      invoice = nil
      Invoice.transaction do
        locked_project = Project.lock.find(project.id)
        remaining = Billing::Capacity.remaining_billable_cents(locked_project, include_drafts: true)
        if total > remaining
          raise InvalidState,
                "This draft would over-commit the accepted commercial amount. Remaining including other drafts: #{Commercial::Money.display(remaining, currency)}."
        end

        recipient = {
          "name" => locked_project.client_organization.name,
          "reference_number" => locked_project.client_organization.reference_number,
          "address" => locked_project.client_organization.address,
          "country" => locked_project.client_organization.country
        }.compact

        invoice = Invoice.create!(
          reference_number: Billing::Reference.generate!,
          operating_organization: locked_project.operating_organization,
          client_organization: locked_project.client_organization,
          project: locked_project,
          quote_id: locked_project.quote_id,
          quote_revision_id: locked_project.quote_revision_id,
          quote_response_id: locked_project.quote_response_id,
          commercial_snapshot: locked_project.commercial_snapshot.deep_dup,
          mode: "simulated",
          issue_status: "draft",
          currency: currency,
          total_cents: total,
          description: attributes[:description].to_s.strip.presence,
          billing_recipient_snapshot: recipient,
          issue_on: parse_date(attributes[:issue_on]) || Time.zone.today,
          due_on: parse_date(attributes[:due_on]),
          payment_terms_text: attributes[:payment_terms_text].to_s.strip.presence ||
                              locked_project.quote_revision&.payment_terms.to_s.strip.presence,
          created_by_membership: @membership
        )

        normalized_lines.each_with_index do |line, index|
          invoice.invoice_line_items.create!(line.merge(position: index + 1))
        end

        Billing::Audit.created(invoice: invoice, actor_membership: @membership)
      end

      Result.new(invoice: invoice)
    end

    private

      def normalize_lines(lines, currency)
        Array(lines).filter_map do |raw|
          raw = raw.to_h.with_indifferent_access
          description = raw[:description].to_s.strip
          next if description.blank?

          quantity = BigDecimal(raw[:quantity].presence || "1")
          raise InvalidState, "Quantity must be greater than zero." if quantity <= 0

          unit_amount = if raw[:unit_amount_cents].present?
            raw[:unit_amount_cents].to_i
          else
            Commercial::Money.parse_minor(raw[:unit_amount].to_s, currency)
          end
          raise InvalidState, "Unit amounts cannot be negative." if unit_amount.negative?

          line_total = (quantity * unit_amount).round(0, BigDecimal::ROUND_HALF_UP).to_i
          {
            description: description,
            quantity: quantity,
            unit: raw[:unit].to_s.strip.presence || "Lot",
            unit_amount_cents: unit_amount,
            line_total_cents: line_total,
            quote_line_item_id: raw[:quote_line_item_id].presence
          }
        end
      rescue Commercial::Money::ParseError => e
        raise InvalidState, e.message
      end

      def parse_date(value)
        return value if value.is_a?(Date)
        return if value.blank?

        Date.iso8601(value.to_s)
      rescue ArgumentError
        raise InvalidState, "Enter dates as YYYY-MM-DD."
      end
  end
end
