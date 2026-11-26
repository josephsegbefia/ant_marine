# frozen_string_literal: true

module Staff
  class InvoiceReleasesController < BaseController
    def revoke
      invoice = policy_scope(Invoice).find(params[:invoice_id])
      release = invoice.invoice_releases.find(params[:id])
      authorize invoice, :revoke_release?
      result = Billing::RevokeRelease.call(
        membership: Current.membership,
        invoice: invoice,
        release: release,
        reason: params[:reason]
      )
      redirect_to staff_invoice_path(result.invoice), notice: "Client invoice access withdrawn."
    rescue Billing::RevokeRelease::Denied, Billing::RevokeRelease::InvalidState, Billing::RevokeRelease::Error => e
      redirect_to staff_invoice_path(invoice), alert: e.message
    end
  end
end
