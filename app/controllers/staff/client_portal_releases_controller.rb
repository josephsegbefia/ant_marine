# frozen_string_literal: true

module Staff
  class ClientPortalReleasesController < BaseController
    before_action :set_client

    def create
      authorize QuotePortalRelease, :create?
      quote = policy_scope(Quote).find(params.require(:quote_id))
      revision = if params[:quote_revision_id].present?
        quote.quote_revisions.find(params[:quote_revision_id])
      else
        quote.current_revision
      end
      raise Clients::ReleaseQuoteToPortal::Error, "Choose a frozen quotation version." unless revision&.version_frozen?

      result = Clients::ReleaseQuoteToPortal.call(
        actor_membership: Current.membership,
        quote: quote,
        quote_revision: revision,
        client_organization: @client,
        label: params[:label]
      )
      redirect_to staff_client_path(@client, tab: "quotations"),
                  notice: "Simulated portal offer released (version #{result.release.quote_revision.version_number})."
    rescue Clients::ReleaseQuoteToPortal::Denied
      redirect_to staff_client_path(@client, tab: "quotations"), alert: "You are not allowed to release quotations to the portal."
    rescue Clients::ReleaseQuoteToPortal::Error, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      redirect_to staff_client_path(@client, tab: "quotations"), alert: e.message
    end

    private

      def set_client
        @client = policy_scope(Organization).find(params[:client_id])
        authorize @client, :show?
      end
  end
end
