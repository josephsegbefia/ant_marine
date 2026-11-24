# frozen_string_literal: true

module StaffQuotationsHelper
  STATUS_LABELS = {
    "draft" => "Draft",
    "pending_review" => "Pending review",
    "approved_for_issuance" => "Approved",
    "issued" => "Issued",
    "withdrawn" => "Withdrawn",
    "superseded" => "Superseded"
  }.freeze

  def quote_status_label(status)
    STATUS_LABELS.fetch(status, status.to_s.humanize)
  end

  def quote_status_badge_variant(status)
    case status
    when "draft" then "ant-badge--warn"
    when "pending_review" then "ant-badge--blue"
    when "approved_for_issuance" then "ant-badge--teal"
    when "issued" then "ant-badge--good"
    when "withdrawn" then "ant-badge--muted"
    else "ant-badge--muted"
    end
  end

  def format_quote_money(cents, currency)
    format("%.2f %s", cents.to_i / 100.0, currency)
  end
end
