# frozen_string_literal: true

module Staff
  class InvoicePaymentsController < BaseController
    before_action :set_invoice

    def create
      authorize @invoice, :record_payment?
      result = Billing::RecordPayment.call(
        membership: Current.membership,
        invoice: @invoice,
        attributes: payment_params
      )
      redirect_to staff_invoice_path(result.invoice), notice: "Payment recorded."
    rescue Billing::RecordPayment::Denied, Billing::RecordPayment::InvalidState, Billing::RecordPayment::Error => e
      redirect_to staff_invoice_path(@invoice), alert: e.message
    end

    def reverse
      authorize @invoice, :reverse_payment?
      payment = @invoice.payment_records.find(params[:id])
      result = Billing::ReversePayment.call(
        membership: Current.membership,
        invoice: @invoice,
        payment: payment,
        reason: params[:reason]
      )
      redirect_to staff_invoice_path(result.invoice), notice: "Payment reversal recorded."
    rescue Billing::ReversePayment::Denied, Billing::ReversePayment::InvalidState, Billing::ReversePayment::Error => e
      redirect_to staff_invoice_path(@invoice), alert: e.message
    end

    private

      def set_invoice
        @invoice = policy_scope(Invoice).find(params[:invoice_id])
      end

      def payment_params
        params.require(:payment).permit(:amount, :payment_on, :payment_method, :external_reference, :internal_note)
      end
  end
end
