# frozen_string_literal: true

module BillingHelper
  def invoice_issue_badge_variant(invoice)
    case invoice.issue_status
    when "draft" then "ant-badge--muted"
    when "issued" then "ant-badge--teal"
    when "void" then "ant-badge--warn"
    else "ant-badge--muted"
    end
  end

  def invoice_payment_badge_variant(invoice)
    case invoice.payment_status
    when "paid" then "ant-badge--good"
    when "partially_paid" then "ant-badge--blue"
    when "unpaid" then invoice.overdue? ? "ant-badge--warn" : "ant-badge--muted"
    else "ant-badge--muted"
    end
  end

  def invoice_payment_display_label(invoice)
    return "Overdue" if invoice.overdue?

    invoice.payment_status_label
  end

  def payment_method_options
    PaymentRecord::METHODS.map { |m| [ m.tr("_", " ").humanize, m ] }
  end
end
