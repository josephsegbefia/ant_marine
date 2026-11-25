# frozen_string_literal: true

module Commercial
  # Records simulated commercial decisions against an exact portal release.
  # Live/binding acceptance remains disabled for F4-04B.
  class QuoteDecision
    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end
    class Conflict < Error; end

    RESPONSES = QuoteResponse::RESPONSES
    Result = Data.define(:response, :created)

    def self.available?
      !Rails.env.production?
    end

    def self.call(membership:, release:, response:, reason: nil, confirmation: false, idempotency_key: nil)
      new(membership: membership).call(
        release: release,
        response: response,
        reason: reason,
        confirmation: confirmation,
        idempotency_key: idempotency_key
      )
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(release:, response:, reason: nil, confirmation: false, idempotency_key: nil)
      raise Denied, "Commercial decisions are not available in production." unless self.class.available?
      raise Denied, "Sign in with an active client membership to continue." unless client_actor?
      raise Error, "Choose Accept, Decline or Request changes." unless response.to_s.in?(RESPONSES)
      raise Error, "Confirm this decision before continuing." unless ActiveModel::Type::Boolean.new.cast(confirmation)

      key = idempotency_key.to_s.presence || SecureRandom.uuid
      existing = QuoteResponse.find_by(idempotency_key: key)
      return Result.new(response: existing, created: false) if existing

      authorize_permission!(response)

      QuoteResponse.transaction do
        locked_release = QuotePortalRelease.lock.find(release.id)
        revision = QuoteRevision.lock.find(locked_release.quote_revision_id)
        quote = Quote.lock.find(locked_release.quote_id)

        validate_release!(locked_release, revision, quote)
        refuse_conflicts!(locked_release, response)

        record = QuoteResponse.create!(
          quote: quote,
          quote_revision: revision,
          quote_portal_release: locked_release,
          client_organization_id: @membership.organization_id,
          responded_by_membership: @membership,
          responded_by_user_id: @membership.user_id,
          response: response.to_s,
          reason: reason.to_s.strip.presence,
          confirmed_at: Time.current,
          mode: "simulated",
          idempotency_key: key,
          offer_snapshot: snapshot_for(quote, revision, locked_release),
          confirmation_evidence: {
            "confirmed" => true,
            "permission" => permission_for(response),
            "role_key" => @membership.role_key
          },
          created_at: Time.current
        )

        audit = AuditEvent.record!(
          organization: Organization.ant_marine!,
          actor_membership: @membership,
          event_type: "quote.decision.#{response}",
          subject: quote,
          metadata: {
            "quote_response_id" => record.id,
            "quote_revision_id" => revision.id,
            "version_number" => revision.version_number,
            "quote_portal_release_id" => locked_release.id,
            "client_organization_id" => @membership.organization_id,
            "mode" => "simulated",
            "response" => record.response
          }
        )

        Notifications::StaffPublisher.quote_decision(
          quote: quote,
          response: record,
          audit_event: audit
        )

        Result.new(response: record, created: true)
      end
    rescue ActiveRecord::RecordNotUnique
      existing = QuoteResponse.find_by(idempotency_key: key)
      return Result.new(response: existing, created: false) if existing

      raise Conflict, "Another decision was recorded for this offer. Refresh and try again."
    end

    private

      def client_actor?
        @membership&.client_domain? && @membership.portal_access? &&
          @membership.user&.status == "active" && @membership.organization&.active?
      end

      def permission_for(response)
        response.to_s == "declined" ? "quotes.decline" : "quotes.accept"
      end

      def authorize_permission!(response)
        key = permission_for(response)
        unless Authorization::EffectivePermissions.allowed?(membership: @membership, permission_key: key)
          raise Denied, "You are not authorised to make this commercial decision for your organisation."
        end
      end

      def validate_release!(release, revision, quote)
        raise InvalidState, "This offer is no longer available." unless release.active?
        raise InvalidState, "Only simulated test offers can be decided in this release." unless release.simulated?
        raise Denied, "This offer belongs to a different organisation." unless release.client_organization_id == @membership.organization_id
        raise InvalidState, "The released version is no longer eligible." unless revision.version_frozen?
        raise InvalidState, "This version has been replaced." if revision.revision_status == "superseded"
        raise InvalidState, "This quotation was withdrawn." if quote.status == "withdrawn"
        if revision.valid_until.present? && revision.valid_until < Time.zone.today
          raise InvalidState, "This offer expired on #{I18n.l(revision.valid_until, format: :long)}."
        end
      end

      def refuse_conflicts!(release, response)
        terminal = QuoteResponse.terminal.where(quote_portal_release_id: release.id).lock.to_a
        if terminal.any?
          existing = terminal.first
          if existing.response == response.to_s
            raise Conflict, "This offer already has a #{existing.response} decision."
          end

          raise Conflict, "This offer already has a final decision (#{existing.response})."
        end
      end

      def snapshot_for(quote, revision, release)
        {
          "reference_number" => quote.reference_number,
          "version_number" => revision.version_number,
          "title" => revision.title,
          "currency" => revision.currency,
          "total_cents" => revision.total_cents,
          "valid_until" => revision.valid_until&.iso8601,
          "payment_terms" => revision.payment_terms,
          "recipient" => revision.recipient_lines,
          "release_id" => release.id,
          "release_mode" => release.mode,
          "release_label" => release.label
        }
      end
  end
end
