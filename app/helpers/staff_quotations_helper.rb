# frozen_string_literal: true

module StaffQuotationsHelper
  STATUS_LABELS = {
    "draft" => "Draft",
    "pending_review" => "Awaiting review",
    "returned_for_correction" => "Returned for correction",
    "approved_for_issuance" => "Approved — not sent",
    "issued" => "Marked issued",
    "withdrawn" => "Withdrawn",
    "superseded" => "Superseded"
  }.freeze

  STATUS_FILTERS = %w[draft pending_review returned_for_correction approved_for_issuance issued withdrawn].freeze

  EDITOR_STEPS = [
    [ 1, "Client" ],
    [ 2, "Scope" ],
    [ 3, "Pricing" ],
    [ 4, "Terms" ],
    [ 5, "Review" ]
  ].freeze

  def quote_status_label(status)
    STATUS_LABELS.fetch(status.to_s, status.to_s.humanize)
  end

  def quote_status_badge_variant(status)
    case status
    when "draft" then "ant-badge--warn"
    when "pending_review" then "ant-badge--blue"
    when "returned_for_correction" then "ant-badge--warn"
    when "approved_for_issuance" then "ant-badge--teal"
    when "issued" then "ant-badge--good"
    else "ant-badge--muted"
    end
  end

  def format_quote_money(cents, currency)
    Commercial::Money.display(cents, currency)
  end

  def quote_delivery_summary(quote)
    if quote.delivery_state == "delivered"
      "Delivery to the client has been confirmed."
    else
      "Not sent to the client. Sending quotations is not available yet."
    end
  end

  def quote_editor_guidance(quote)
    case quote.status
    when "draft" then "Drafts can be saved incomplete. Everything must be filled in before you submit for review."
    when "returned_for_correction" then "A reviewer asked for corrections. Update the quotation, then submit it for review again."
    when "pending_review" then "This quotation is waiting for a reviewer. Its content is read-only until it is approved or returned."
    when "approved_for_issuance" then "This version is approved and locked. It has not been sent to the client."
    when "issued" then "This version is locked. Delivery to the client has not been confirmed."
    when "withdrawn" then "This quotation was withdrawn and can no longer be changed."
    else "This quotation can no longer be changed."
    end
  end

  HISTORY_LABELS = {
    "quote.created" => "Draft started",
    "quote.submit_for_review" => "Submitted for review",
    "quote.return_for_correction" => "Returned for correction",
    "quote.approve" => "Approved",
    "quote.issue" => "Marked issued",
    "quote.withdraw" => "Withdrawn"
  }.freeze

  def quote_history_label(event_type)
    HISTORY_LABELS.fetch(event_type, "Updated")
  end
end
