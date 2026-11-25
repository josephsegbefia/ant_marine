# frozen_string_literal: true

module Clients
  # Client portal quotation visibility: only active simulated (or future live)
  # portal releases for the caller's organisation. Organization linkage alone
  # is never enough.
  class PortalQuoteVisibility
    def self.releases_for(membership:)
      new(membership: membership).releases
    end

    def self.find_release!(membership:, release_id:)
      new(membership: membership).find_release!(release_id)
    end

    def initialize(membership:)
      @membership = membership
    end

    def releases
      return QuotePortalRelease.none unless client_viewer?

      QuotePortalRelease.active
                        .for_client_organization(@membership.organization)
                        .includes(:quote, :quote_revision)
                        .order(released_at: :desc)
    end

    def find_release!(release_id)
      releases.find(release_id)
    end

    def find_release_for_quote_version!(quote_id:, version_number:)
      releases.joins(:quote_revision)
              .where(quote_id: quote_id, quote_revisions: { version_number: version_number })
              .first!
    end

    private

      def client_viewer?
        @membership&.client_domain? && @membership.portal_access? &&
          Authorization::EffectivePermissions.allowed?(
            membership: @membership,
            permission_key: "quotes.view_org"
          )
      end
  end
end
