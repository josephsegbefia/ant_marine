# frozen_string_literal: true

module StaffEnquiriesHelper
  def enquiry_status_badge_variant(status)
    case status
    when "submitted" then "ant-badge--blue"
    when "under_review", "needs_clarification" then "ant-badge--warn"
    when "qualified" then "ant-badge--teal"
    else "ant-badge--muted"
    end
  end

  def enquiry_quote_progress(inquiry)
    quote = inquiry.quotes.reject { |q| q.status.in?(%w[withdrawn superseded]) }.min_by(&:created_at)
    return "Not quoted yet" unless quote

    "Quotation #{quote.reference_number} — #{quote_status_label(quote.status).downcase}"
  end

  def enquiry_channel_label(channel)
    {
      "public_form" => "Website request form",
      "contact_form" => "Website contact form",
      "client_portal" => "Client workspace",
      "staff" => "Entered by staff"
    }.fetch(channel.to_s, channel.to_s.humanize)
  end

  def enquiry_history_label(event_type)
    {
      "service_inquiry.submitted" => "Request received",
      "service_inquiry.quotation_started" => "Quotation started"
    }.fetch(event_type, event_type.to_s.split(".").last.humanize)
  end
end
