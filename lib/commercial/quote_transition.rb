# frozen_string_literal: true

module Commercial
  class QuoteTransition
    class InvalidTransition < StandardError; end

    TRANSITIONS = {
      "submit_for_review" => { from: "draft", to: "pending_review", revision: "pending_review" },
      "return_for_correction" => { from: "pending_review", to: "draft", revision: "draft" },
      "approve" => { from: "pending_review", to: "approved_for_issuance", revision: "approved", freeze: true },
      "issue" => { from: "approved_for_issuance", to: "issued", revision: "issued", freeze: true, delivery: "prepared" },
      "withdraw" => { from: %w[draft pending_review approved_for_issuance issued], to: "withdrawn", revision: nil }
    }.freeze

    def self.apply!(quote:, action:, membership:, reason: nil)
      new(quote:, action:, membership:, reason:).apply!
    end

    def initialize(quote:, action:, membership:, reason: nil)
      @quote = quote
      @action = action.to_s
      @membership = membership
      @reason = reason
    end

    def apply!
      rule = TRANSITIONS.fetch(@action) do
        raise InvalidTransition, "Unknown quotation action."
      end

      allowed_from = Array(rule[:from])
      raise InvalidTransition, "Quotation cannot move from #{@quote.status}." unless allowed_from.include?(@quote.status)

      authorize_action!(rule)

      previous_status = @quote.status
      revision = @quote.current_revision

      Quote.transaction do
        @quote.update!(
          status: rule[:to],
          delivery_state: rule[:delivery].presence || @quote.delivery_state,
          updated_by_membership: @membership,
          lock_version: @quote.lock_version
        )

        if revision && rule[:revision]
          attrs = { revision_status: rule[:revision] }
          if rule[:freeze]
            attrs[:frozen_at] = Time.current
            attrs[:recipient_snapshot] = recipient_snapshot(revision)
          end
          attrs[:approved_by_membership] = @membership if @action == "approve"
          attrs[:approved_at] = Time.current if @action == "approve"
          attrs[:issued_by_membership] = @membership if @action == "issue"
          attrs[:issued_at] = Time.current if @action == "issue"
          revision.update!(attrs)
        end

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
            reason: @reason
          }.compact
        )
      end

      @quote
    end

    private

      def authorize_action!(rule)
        case @action
        when "submit_for_review", "return_for_correction"
          raise InvalidTransition, "Not authorized." unless allowed?("quotes.create")
        when "approve"
          raise InvalidTransition, "Not authorized." unless allowed?("quotes.approve")
        when "issue"
          raise InvalidTransition, "Not authorized." unless allowed?("quotes.send")
        when "withdraw"
          raise InvalidTransition, "Not authorized." unless allowed?("quotes.withdraw")
        end
      end

      def allowed?(key)
        Authorization::EffectivePermissions.allowed?(membership: @membership, permission_key: key)
      end

      def recipient_snapshot(revision)
        {
          company_name: @quote.client_label,
          contact_name: @quote.prospective_client["contact_name"],
          email: @quote.prospective_client["email"],
          phone: @quote.prospective_client["phone"],
          address: @quote.prospective_client["address"]
        }.compact.merge(
          title: revision.title,
          currency: revision.currency
        )
      end
  end
end
