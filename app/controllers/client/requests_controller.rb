# frozen_string_literal: true

module Client
  class RequestsController < BaseController
    def index
      authorize ServiceInquiry, :index?
      scope = policy_scope(ServiceInquiry).recent_first
      @pagination = Pagination.new(scope, page: params[:page], per_page: 25)
      @requests = @pagination.records
    end

    def show
      @request = policy_scope(ServiceInquiry).find(params[:id])
      authorize @request
      @releases = QuotePortalRelease.active
                                    .where(client_organization_id: Current.membership.organization_id, quote_id: @request.quotes.select(:id))
                                    .includes(:quote, :quote_revision)
                                    .order(released_at: :desc)
    end
  end
end
