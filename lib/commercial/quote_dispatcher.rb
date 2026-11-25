# frozen_string_literal: true

module Commercial
  # Prepares and queues the sending of one exact approved version. Every step re-checks,
  # under a row lock, that the version is still the approved current version, still in
  # date, addressed to a usable recipient and requested by someone allowed to send.
  class QuoteDispatcher
    class Refused < QuoteTransition::InvalidTransition; end

    def self.prepare!(quote:, membership:, expected_version:)
      new(quote:, membership:).prepare!(expected_version)
    end

    def self.dispatch!(quote:, membership:, delivery_id:)
      new(quote:, membership:).dispatch!(delivery_id)
    end

    def self.cancel!(quote:, membership:, delivery_id:)
      new(quote:, membership:).cancel!(delivery_id)
    end

    # Reasons the current version cannot be sent; empty when it can.
    def self.blockers(quote:, membership:)
      new(quote:, membership:).blockers
    end

    def initialize(quote:, membership:)
      @quote = quote
      @membership = membership
    end

    def blockers
      revision = @quote.current_revision
      issues = []
      issues << QuoteIssuance::DISPATCH_DISABLED_MESSAGE unless QuoteIssuance.dispatch_available?
      issues << "You do not have permission to send quotations." unless permitted?
      unless @quote.status == "approved_for_issuance" && revision&.revision_status == "approved" && revision.version_frozen?
        issues << "Only an approved version that has not been sent can be prepared for sending."
        return issues
      end
      issues << "This version has no recorded independent approval." if revision.approved_by_membership_id.blank?
      if revision.valid_until.blank? || revision.valid_until < Date.current
        issues << "This version expired on #{I18n.l(revision.valid_until, format: :long)}. Create a new version with a new validity date." if revision.valid_until
        issues << "This version has no validity date." if revision.valid_until.blank?
      end
      issues.concat(recipient_issues(revision))
      issues
    end

    def prepare!(expected_version)
      Quote.transaction do
        @quote.lock!
        revision = @quote.current_revision
        revision&.lock!
        ensure_expected_version!(revision, expected_version)
        refuse_if_blocked!
        if QuoteDelivery.live_for(revision)
          raise Refused, "This version already has a delivery in progress or completed. It will not be sent twice."
        end

        recipient = revision.recipient_lines.to_h.stringify_keys
        delivery = QuoteDelivery.create!(
          organization: @quote.organization,
          quote: @quote,
          quote_revision: revision,
          requested_by_membership: @membership,
          status: "prepared",
          delivery_adapter: QuoteIssuance.adapter_name,
          idempotency_key: SecureRandom.uuid,
          recipient_email: recipient["email"],
          recipient_name: recipient["contact_name"],
          recipient_company: recipient["company_name"],
          prepared_at: Time.current
        )
        sync_quote_state!(delivery)
        audit!("quote.delivery_prepared", delivery)
        delivery
      end
    rescue ActiveRecord::RecordNotUnique
      raise Refused, "This version already has a delivery in progress or completed. It will not be sent twice."
    end

    def dispatch!(delivery_id)
      Quote.transaction do
        @quote.lock!
        delivery = QuoteDelivery.lock.find_by!(id: delivery_id, quote_id: @quote.id)
        return delivery if delivery.status.in?(%w[queued sending accepted_by_provider delivery_confirmed])
        raise Refused, "This delivery can no longer be sent (#{delivery.status_label.downcase})." unless delivery.status == "prepared"
        raise Refused, "A newer version exists. Prepare the current version instead." unless delivery.quote_revision_id == @quote.current_revision_id

        refuse_if_blocked!
        delivery.update!(status: "queued", queued_at: Time.current, dispatched_by_membership: @membership)
        sync_quote_state!(delivery)
        audit!("quote.delivery_queued", delivery)
        DeliverQuoteJob.perform_later(delivery.id)
        delivery
      end
    end

    def cancel!(delivery_id)
      Quote.transaction do
        @quote.lock!
        delivery = QuoteDelivery.lock.find_by!(id: delivery_id, quote_id: @quote.id)
        raise Refused, "Only a prepared delivery that has not been queued can be cancelled." unless delivery.status == "prepared"
        raise Refused, "You do not have permission to send quotations." unless permitted?

        delivery.update!(status: "cancelled", cancelled_at: Time.current)
        sync_quote_state!(delivery)
        audit!("quote.delivery_cancelled", delivery)
        delivery
      end
    end

    private

      def permitted?
        @membership&.status == "active" && @membership.user&.status == "active" &&
          QuotePolicy.new(@membership, @quote).send_quotation?
      end

      def refuse_if_blocked!
        issues = blockers
        raise Refused, issues.first if issues.any?
      end

      def ensure_expected_version!(revision, expected_version)
        expected = expected_version.to_h.symbolize_keys
        current = revision.present? &&
                  expected[:revision_id].to_s == revision.id.to_s &&
                  expected[:lock_version].to_s == @quote.lock_version.to_s
        raise QuoteTransition::StaleVersion, QuoteTransition::STALE_MESSAGE unless current
      end

      def recipient_issues(revision)
        recipient = revision.recipient_lines.to_h.stringify_keys
        issues = []
        email = recipient["email"].to_s
        issues << "The approved version has no recipient email address." if email.blank?
        issues << "The recipient email address on the approved version is not valid." if email.present? && !email.match?(ServiceInquiry::EMAIL_FORMAT)
        client_id = recipient["client_organization_id"]
        if client_id.present? && !Quote.assignable_client_organizations(@quote.organization).exists?(id: client_id)
          issues << "The client organisation on this version is no longer active."
        end
        issues
      end

      def sync_quote_state!(delivery)
        @quote.update_columns(delivery_state: delivery.quote_delivery_state, updated_at: Time.current)
      end

      def audit!(event_type, delivery)
        AuditEvent.record!(
          event_type: event_type,
          organization: @quote.organization,
          actor_membership: @membership,
          subject: @quote,
          metadata: {
            reference_number: @quote.reference_number,
            delivery_id: delivery.id,
            revision_id: delivery.quote_revision_id,
            version_number: delivery.quote_revision.version_number,
            delivery_status: delivery.status,
            delivery_adapter: delivery.delivery_adapter
          }
        )
      end
  end
end
