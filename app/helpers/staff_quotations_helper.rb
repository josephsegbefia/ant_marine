# frozen_string_literal: true

module StaffQuotationsHelper
  STATUS_LABELS = {
    "draft" => "Draft",
    "pending_review" => "Awaiting review",
    "returned_for_correction" => "Returned for correction",
    "approved_for_issuance" => "Approved — not sent",
    "issued" => "Sent — not confirmed",
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
    delivery = quote.quote_deliveries.where(quote_revision_id: quote.current_revision_id).recent_first.first
    return delivery.status_label if delivery

    current = quote.status == "approved_for_issuance" ? "Approved — not sent" : "Not sent to the client."
    outstanding = quote.quote_revisions.where(revision_status: "issued").where.not(id: quote.current_revision_id)
                       .order(version_number: :desc).first
    return current unless outstanding

    "#{current.delete_suffix('.')}. Version #{outstanding.version_number} was sent earlier and is still the client’s offer."
  end

  def quote_editor_guidance(quote)
    case quote.status
    when "draft" then "Drafts can be saved incomplete. Everything must be filled in before you submit for review."
    when "returned_for_correction" then "A reviewer asked for corrections. Update the quotation, then submit it for review again."
    when "pending_review" then "This quotation is waiting for a reviewer. Its content is read-only until it is approved or returned."
    when "approved_for_issuance" then "This version is approved and locked. It has not been sent to the client."
    when "issued" then "This version was sent by email and is locked. Delivery to the client has not been confirmed."
    when "withdrawn" then "This quotation was withdrawn and can no longer be changed."
    else "This quotation can no longer be changed."
    end
  end

  HISTORY_LABELS = {
    "quote.created" => "Draft started",
    "quote.submit_for_review" => "Submitted for review",
    "quote.return_for_correction" => "Returned for correction",
    "quote.approve" => "Approved",
    "quote.approval_refused" => "Approval refused — another reviewer needed",
    "quote.issue" => "Marked issued",
    "quote.withdraw" => "Withdrawn",
    "quote.revision_created" => "New version started",
    "quote.delivery_prepared" => "Prepared for sending",
    "quote.delivery_queued" => "Queued for sending",
    "quote.delivery_cancelled" => "Prepared delivery cancelled",
    "quote.delivery_accepted" => "Accepted by the mail system",
    "quote.delivery_failed" => "Delivery failed",
    "quote.delivery_outcome_unknown" => "Delivery outcome unknown",
    "quote.created_from_inquiry" => "Started from an enquiry"
  }.freeze

  def quote_revision_status_label(revision, quote)
    case revision.revision_status
    when "draft" then revision.id == quote.current_revision_id ? "Current working draft" : "Draft"
    when "pending_review" then "Awaiting review"
    when "approved" then "Approved — not sent"
    when "issued" then "Issued — outstanding offer"
    when "superseded" then "Superseded"
    else revision.revision_status.humanize
    end
  end

  def quote_revision_badge_variant(revision)
    case revision.revision_status
    when "draft" then "ant-badge--warn"
    when "pending_review" then "ant-badge--blue"
    when "approved" then "ant-badge--teal"
    when "issued" then "ant-badge--good"
    else "ant-badge--muted"
    end
  end

  def quote_member_name(membership)
    return "Not recorded" if membership.nil?

    membership.user&.full_name.presence || membership.user&.email.to_s.split("@").first.to_s.titleize.presence || "Staff member"
  end

  def quote_history_label(event_type)
    HISTORY_LABELS.fetch(event_type, "Updated")
  end

  def quotation_index_path_with(overrides = {})
    current = {
      q: @filters&.dig(:q),
      status: @filters&.dig(:status)
    }
    staff_quotations_path(current.merge(overrides).compact_blank)
  end

  def quotation_filters_active?(filters = @filters)
    filters.to_h.values.any?(&:present?)
  end
end
