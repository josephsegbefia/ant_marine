# frozen_string_literal: true

module Clients
  # Simulated portal release only — live commercial release is not authorised in F4-04A.
  class ReleaseQuoteToPortal
    class Error < StandardError; end
    class Denied < Error; end

    Result = Data.define(:release)

    def self.call(actor_membership:, quote:, quote_revision:, client_organization:, label: nil)
      new(actor_membership: actor_membership).call(
        quote: quote,
        quote_revision: quote_revision,
        client_organization: client_organization,
        label: label
      )
    end

    def initialize(actor_membership:)
      @actor = actor_membership
    end

    def call(quote:, quote_revision:, client_organization:, label: nil)
      authorize!
      raise Error, "Simulated portal release is not available in production." if Rails.env.production?
      raise Error, "Choose an active client organisation." unless client_organization&.client? && client_organization.active?
      raise Error, "The quotation must belong to the ANT Marine workspace." unless quote.organization.ant_marine?
      raise Error, "Release the exact approved or issued version only." unless quote_revision.quote_id == quote.id
      raise Error, "Only frozen approved or issued versions can be released." unless quote_revision.version_frozen?

      if quote.client_organization_id.present? && quote.client_organization_id != client_organization.id
        raise Error, "This quotation is linked to a different client organisation."
      end

      release = nil
      QuotePortalRelease.transaction do
        release = QuotePortalRelease.create!(
          quote: quote,
          quote_revision: quote_revision,
          client_organization: client_organization,
          released_by_membership: @actor,
          mode: "simulated",
          released_at: Time.current,
          label: label.presence || "Simulated offer for portal testing"
        )

        if quote.client_organization_id.blank?
          quote.update_columns(client_organization_id: client_organization.id, updated_at: Time.current)
        end
      end

      AuditEvent.record!(
        organization: Organization.ant_marine!,
        actor_membership: @actor,
        event_type: "quote.portal_release.simulated",
        subject: quote,
        metadata: {
          "quote_revision_id" => quote_revision.id,
          "version_number" => quote_revision.version_number,
          "client_organization_id" => client_organization.id,
          "release_id" => release.id,
          "mode" => "simulated"
        }
      )

      Result.new(release: release)
    end

    private

      def authorize!
        unless @actor&.staff_domain? && @actor.portal_access? &&
               Authorization::EffectivePermissions.allowed?(membership: @actor, permission_key: "quotes.send")
          raise Denied, "You are not allowed to release quotations to the client portal."
        end
      end
  end
end
