# frozen_string_literal: true

module Staff
  class QuotationIssuancesController < BaseController
    before_action :set_quote

    def show
      authorize @quote, :issuance?
      @revision = @quote.current_revision
      @deliveries = @quote.quote_deliveries.includes(:quote_revision, requested_by_membership: :user).recent_first
      @current_delivery = @deliveries.find { |d| d.quote_revision_id == @revision.id && d.status != "cancelled" }
      @blockers = Commercial::QuoteDispatcher.blockers(quote: @quote, membership: Current.membership)
      assign_staff_breadcrumb(
        crumbs: [ { label: "Quotations", path: staff_quotations_path },
                  { label: @quote.reference_number, path: edit_staff_quotation_path(@quote) } ],
        current: "Send to client"
      )
    end

    def create
      authorize @quote, :send_quotation?
      unless params[:confirm_checked] == "1"
        redirect_to staff_quotation_issuance_path(@quote), alert: "Confirm that you have checked the recipient and the PDF."
        return
      end
      Commercial::QuoteDispatcher.prepare!(
        quote: @quote,
        membership: Current.membership,
        expected_version: { revision_id: params[:expected_revision_id], lock_version: params[:expected_lock_version] }
      )
      redirect_to staff_quotation_issuance_path(@quote), notice: "Prepared for sending. Nothing has been sent yet."
    rescue Commercial::QuoteTransition::InvalidTransition => e
      redirect_to staff_quotation_issuance_path(@quote), alert: e.message
    end

    def deliver
      authorize @quote, :send_quotation?
      Commercial::QuoteDispatcher.dispatch!(quote: @quote, membership: Current.membership, delivery_id: params[:delivery_id])
      redirect_to staff_quotation_issuance_path(@quote),
                  notice: "Queued for sending. The status below updates when the mail system answers."
    rescue Commercial::QuoteTransition::InvalidTransition => e
      redirect_to staff_quotation_issuance_path(@quote), alert: e.message
    end

    def cancel
      authorize @quote, :send_quotation?
      Commercial::QuoteDispatcher.cancel!(quote: @quote, membership: Current.membership, delivery_id: params[:delivery_id])
      redirect_to staff_quotation_issuance_path(@quote), notice: "Prepared delivery cancelled. Nothing was sent."
    rescue Commercial::QuoteTransition::InvalidTransition => e
      redirect_to staff_quotation_issuance_path(@quote), alert: e.message
    end

    private

      def set_quote
        @quote = policy_scope(Quote).find(params[:quotation_id])
      end
  end
end
