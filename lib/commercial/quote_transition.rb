# frozen_string_literal: true

module Commercial
  class QuoteTransition
    class InvalidTransition < StandardError; end
    class NotAuthorized < InvalidTransition; end

    class NotReady < InvalidTransition
      attr_reader :issues

      def initialize(issues)
        @issues = issues
        super("This quotation is not ready yet.")
      end
    end

    TRANSITIONS = {
      "submit_for_review" => { from: Quote::EDITABLE_STATUSES, to: "pending_review", revision: "pending_review", readiness: true },
      "return_for_correction" => { from: %w[pending_review], to: "returned_for_correction", revision: "draft", reason_required: true },
      "approve" => { from: %w[pending_review], to: "approved_for_issuance", revision: "approved", freeze: true, readiness: true },
      "issue" => { from: %w[approved_for_issuance], to: "issued", revision: "issued", gated: true },
      "withdraw" => { from: %w[draft pending_review returned_for_correction approved_for_issuance issued], to: "withdrawn", revision: nil }
    }.freeze

    STATUS_MESSAGES = {
      "pending_review" => "This quotation is already waiting for review.",
      "approved_for_issuance" => "This quotation has already been approved.",
      "issued" => "This quotation has already been marked as issued.",
      "withdrawn" => "This quotation has been withdrawn.",
      "superseded" => "This quotation has been replaced by a newer version."
    }.freeze

    def self.apply!(quote:, action:, membership:, reason: nil)
      new(quote:, action:, membership:, reason:).apply!
    end

    def initialize(quote:, action:, membership:, reason: nil)
      @quote = quote
      @action = action.to_s
      @membership = membership
      @reason = reason.to_s.strip.presence
    end

    def apply!
      rule = TRANSITIONS.fetch(@action) { raise InvalidTransition, "Unknown quotation action." }

      Quote.transaction do
        @quote.lock!
        revision = @quote.current_revision
        revision&.lock!
        previous_status = @quote.status

        unless rule[:from].include?(previous_status)
          raise InvalidTransition, STATUS_MESSAGES.fetch(previous_status, "This quotation cannot do that in its current state.")
        end
        raise InvalidTransition, QuoteIssuance::UNAVAILABLE_MESSAGE if rule[:gated] && !QuoteIssuance.available?
        raise NotAuthorized, "You do not have permission to do that." unless authorized?
        raise InvalidTransition, "Explain what needs to be corrected." if rule[:reason_required] && @reason.nil?

        if rule[:readiness]
          issues = QuoteReadiness.check(@quote)
          raise NotReady, issues if issues.any?
        end

        @quote.update!(status: rule[:to], updated_by_membership: @membership)
        revision.update!(revision_attributes(rule, revision)) if revision && rule[:revision]

        AuditEvent.record!(
          event_type: "quote.#{@action}",
          organization: @quote.organization,
          actor_membership: @membership,
          subject: @quote,
          metadata: {
            reference_number: @quote.reference_number,
            previous_status: previous_status,
            new_status: @quote.status,
            version_number: revision&.version_number,
            total_cents: revision&.total_cents,
            currency: revision&.currency,
            reason: @reason
          }.compact
        )
      end

      @quote
    end

    private

      def authorized?
        return false if @membership.nil?

        QuotePolicy.new(@membership, @quote).public_send(:"#{@action}?")
      end

      def revision_attributes(rule, revision)
        attrs = { revision_status: rule[:revision] }
        if rule[:freeze]
          now = Time.current
          attrs[:frozen_at] = now
          attrs[:recipient_snapshot] = recipient_snapshot(revision)
          attrs[:approved_by_membership] = @membership
          attrs[:approved_at] = now
        end
        if @action == "issue"
          attrs[:issued_by_membership] = @membership
          attrs[:issued_at] = Time.current
        end
        attrs
      end

      def recipient_snapshot(revision)
        {
          company_name: @quote.client_label,
          client_organization_id: @quote.client_organization_id,
          contact_name: @quote.prospective_value("contact_name").presence,
          email: @quote.prospective_value("email").presence,
          phone: @quote.prospective_value("phone").presence,
          address: @quote.prospective_value("address").presence,
          service_title: @quote.service&.title,
          title: revision.title,
          currency: revision.currency
        }.compact
      end
  end
end
