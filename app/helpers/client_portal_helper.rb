# frozen_string_literal: true

module ClientPortalHelper
  CLIENT_REQUEST_STATUSES = {
    "submitted" => "Received",
    "under_review" => "Under review",
    "needs_clarification" => "Waiting for information",
    "qualified" => "Ready for quotation",
    "unqualified" => "Closed — outside scope",
    "merged" => "Closed — duplicate",
    "closed" => "Closed"
  }.freeze

  def client_can_view_requests?
    return false unless Current.membership&.client_domain?

    Authorization::EffectivePermissions.allowed?(
      membership: Current.membership,
      permission_key: "inquiries.view_org"
    )
  end

  def client_can_view_quotations?
    return false unless Current.membership&.client_domain?

    Authorization::EffectivePermissions.allowed?(
      membership: Current.membership,
      permission_key: "quotes.view_org"
    )
  end

  def client_request_status_label(status)
    CLIENT_REQUEST_STATUSES.fetch(status, status.to_s.humanize)
  end

  def client_money(cents, currency)
    amount = (cents.to_i / 100.0)
    "#{currency} #{format('%.2f', amount)}"
  end
end
