# frozen_string_literal: true

class QuotesMailer < ApplicationMailer
  def quotation(delivery)
    @delivery = delivery
    @quote = delivery.quote
    @revision = delivery.quote_revision
    @recipient_name = delivery.recipient_name.presence || delivery.recipient_company.presence || "Sir or Madam"

    attachments[pdf_filename] = {
      mime_type: "application/pdf",
      content: Commercial::QuotePdfRenderer.render(quote: @quote, revision: @revision)
    }

    mail(
      to: delivery.recipient_email,
      subject: "Quotation #{@quote.reference_number} (version #{@revision.version_number}) from ANT Marine W.A.",
      message_id: "<quote-delivery-#{delivery.idempotency_key}@ant-marine.local>"
    )
  end

  private

    def pdf_filename
      "#{@quote.reference_number}-v#{@revision.version_number}.pdf"
    end
end
