# frozen_string_literal: true

module Client
  class QuotationsController < BaseController
    def index
      authorize QuotePortalRelease, :index?
      @releases = Clients::PortalQuoteVisibility.releases_for(membership: Current.membership)
      @pagination = Pagination.new(@releases, page: params[:page], per_page: 25)
      @releases = @pagination.records
    end

    def show
      @release = Clients::PortalQuoteVisibility.find_release!(membership: Current.membership, release_id: params[:id])
      authorize @release
      @quote = @release.quote
      @revision = @release.quote_revision
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def pdf
      @release = Clients::PortalQuoteVisibility.find_release!(membership: Current.membership, release_id: params[:id])
      authorize @release, :pdf?
      pdf = Commercial::QuotePdfRenderer.render(quote: @release.quote, revision: @release.quote_revision)
      response.headers["Cache-Control"] = "private, no-store"
      filename = "#{@release.quote.reference_number}-v#{@release.quote_revision.version_number}"
      filename += "-SIMULATED" if @release.simulated?
      send_data pdf, filename: "#{filename}.pdf", type: "application/pdf", disposition: "inline"
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
