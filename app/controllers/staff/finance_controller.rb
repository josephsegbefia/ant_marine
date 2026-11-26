# frozen_string_literal: true

module Staff
  class FinanceController < BaseController
    def show
      authorize Invoice, :finance_dashboard?
      @currency = params[:currency].presence_in(Commercial::Money::MINOR_UNITS.keys)
      @summaries = Billing::Dashboard.summaries_for(membership: Current.membership, currency: @currency)
      @recent = policy_scope(Invoice).includes(:client_organization, :project).recent_first.limit(10)
      assign_staff_breadcrumb(crumbs: [], current: "Finance")
    end
  end
end
