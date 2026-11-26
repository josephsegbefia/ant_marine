# frozen_string_literal: true

module Client
  class InvoicesController < BaseController
    before_action :set_invoice, only: %i[show download]

    def index
      authorize Invoice
      @invoices = policy_scope(Invoice).includes(:project, :payment_records).recent_first
    end

    def show
      authorize @invoice
      @payments = @invoice.payment_records.includes(:payment_reversal).recent_first
    end

    def download
      authorize @invoice, :download?
      payload = Billing::SecureDownload.call(membership: Current.membership, invoice: @invoice)
      send_data payload.bytes,
                filename: payload.filename,
                type: payload.content_type,
                disposition: "attachment"
      response.headers["Cache-Control"] = "private, no-store"
    rescue Billing::SecureDownload::Denied, Billing::SecureDownload::InvalidState => e
      redirect_to client_invoice_path(@invoice), alert: e.message
    end

    private

      def set_invoice
        @invoice = policy_scope(Invoice).find(params[:id])
      end
  end
end
