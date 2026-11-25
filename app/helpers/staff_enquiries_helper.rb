# frozen_string_literal: true

module StaffEnquiriesHelper
  ACTION_LABELS = {
    "start_review" => "Start review",
    "qualify" => "Mark ready to quote",
    "mark_outside_scope" => "Mark outside our scope",
    "mark_duplicate" => "Mark as duplicate",
    "close" => "Close enquiry",
    "reopen" => "Reopen enquiry"
  }.freeze

  def enquiry_status_badge_variant(status)
    case status
    when "submitted" then "ant-badge--blue"
    when "under_review", "needs_clarification" then "ant-badge--warn"
    when "qualified" then "ant-badge--teal"
    else "ant-badge--muted"
    end
  end

  def enquiry_action_label(action)
    ACTION_LABELS.fetch(action, action.humanize)
  end

  # Derived from the quotations themselves, so the enquiry never claims more than has happened.
  def enquiry_quote_progress(inquiry)
    quotes = inquiry.quotes.to_a
    quote = quotes.reject { |q| q.status.in?(%w[withdrawn superseded]) }.min_by(&:created_at)
    return quotes.any? ? "Quotation withdrawn — none in progress" : "Not quoted yet" unless quote

    "Quotation #{quote.reference_number} — #{enquiry_quote_stage(quote)}"
  end

  def enquiry_quote_stage(quote)
    case quote.status
    when "draft" then "draft being prepared"
    when "pending_review" then "waiting for approval"
    when "returned_for_correction" then "returned for changes"
    when "approved_for_issuance" then "approved, not sent"
    when "issued" then enquiry_issued_stage(quote)
    else quote_status_label(quote.status).downcase
    end
  end

  def enquiry_assignee_name(membership)
    membership ? Intake::InquiryAssignment.display_name(membership) : "Unassigned"
  end

  def enquiry_member_name(membership)
    membership&.user&.full_name.presence || "A team member"
  end

  def enquiry_channel_label(channel)
    {
      "public_form" => "Website request form",
      "contact_form" => "Website contact form",
      "client_portal" => "Client workspace",
      "staff" => "Entered by staff"
    }.fetch(channel.to_s, channel.to_s.humanize)
  end

  def enquiry_filters_active?(filters)
    filters.values.any?(&:present?)
  end

  def enquiry_index_path_with(overrides = {})
    current = {
      view: (@view unless @view == "all"),
      q: @filters[:q], status: @filters[:status], assignee: @filters[:assignee],
      from: @filters[:from]&.iso8601, to: @filters[:to]&.iso8601
    }
    staff_service_inquiries_path(current.merge(overrides).compact_blank)
  end

  def enquiry_empty_state_copy(view, filters_active)
    return [ "No enquiries match these filters", "Try a different search or clear the filters." ] if filters_active

    {
      "mine" => [ "Nothing assigned to you", "Enquiries you are responsible for will appear here." ],
      "unassigned" => [ "Every open enquiry has someone responsible", "New requests without a responsible person will appear here." ],
      "awaiting" => [ "Nothing is waiting on a client", "Enquiries appear here once you record that you have asked the client for more information." ],
      "closed" => [ "No closed enquiries", "Enquiries that are closed, outside our scope or duplicates will appear here." ]
    }.fetch(view, [ "No enquiries yet", "Requests sent through the website’s “Request a quote” form will appear here." ])
  end

  private

    def enquiry_issued_stage(quote)
      delivery = quote.quote_deliveries.select { |d| d.status.in?(%w[accepted_by_provider delivery_confirmed]) }.max_by(&:id)
      return "issued, not sent" unless delivery
      return "sent in test mode — no real email was sent" if delivery.local_adapter?

      "sent — delivery not confirmed"
    end
end
