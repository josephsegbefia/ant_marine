# frozen_string_literal: true

require "prawn"
require "prawn/table"

module Billing
  module PdfRenderer
    module_function

    def render(invoice:, draft: false)
      invoice = invoice.is_a?(Invoice) ? invoice : Invoice.find(invoice)
      lines = invoice.invoice_line_items.to_a

      Prawn::Document.new(page_size: "A4", margin: 48) do |pdf|
        pdf.fill_color "102C43"
        pdf.text "ANT Marine W.A.", size: 18, style: :bold
        pdf.fill_color "25877F"
        pdf.text "Consulting Services", size: 10
        pdf.move_down 8

        pdf.fill_color "8a5a10"
        banner = draft ? "SIMULATED DRAFT — NOT PAYABLE" : "SIMULATED — NOT PAYABLE"
        pdf.text banner, size: 12, style: :bold
        pdf.fill_color "466270"
        pdf.text "This document is for authorised testing only. It is not a tax invoice and creates no payment obligation.", size: 9
        pdf.move_down 16

        pdf.fill_color "102C43"
        pdf.text draft ? "Draft invoice" : "Invoice", size: 16, style: :bold
        pdf.fill_color "466270"
        pdf.text invoice.reference_number, size: 11
        pdf.text "Issue date: #{invoice.issue_on || Time.zone.today}"
        pdf.text "Due date: #{invoice.due_on || '—'}"
        pdf.move_down 12

        recipient = invoice.billing_recipient_snapshot || {}
        pdf.fill_color "102C43"
        pdf.text "Bill to", size: 11, style: :bold
        pdf.fill_color "466270"
        pdf.text recipient["name"].presence || invoice.client_organization.name
        pdf.text [ recipient["address"], recipient["country"] ].compact.join(", ") if recipient["address"].present? || recipient["country"].present?
        pdf.move_down 10

        pdf.fill_color "102C43"
        pdf.text "Project", size: 11, style: :bold
        pdf.fill_color "466270"
        pdf.text "#{invoice.project.reference_number} — #{invoice.project.title}"
        pdf.text "Accepted quotation: #{invoice.quote.reference_number} · Version #{invoice.quote_revision.version_number}"
        pdf.move_down 12

        if invoice.description.present?
          pdf.fill_color "102C43"
          pdf.text "Description", size: 11, style: :bold
          pdf.fill_color "466270"
          pdf.text invoice.description
          pdf.move_down 10
        end

        table_data = [ [ "Item", "Qty", "Unit", "Amount", "Total" ] ]
        lines.each do |line|
          table_data << [
            line.description,
            line.quantity.to_s("F"),
            line.unit,
            Commercial::Money.display(line.unit_amount_cents, invoice.currency),
            Commercial::Money.display(line.line_total_cents, invoice.currency)
          ]
        end
        table_data << [ { content: "Total", colspan: 4, align: :right, font_style: :bold },
                        { content: Commercial::Money.display(invoice.total_cents, invoice.currency), font_style: :bold } ]

        pdf.table(table_data, width: pdf.bounds.width, cell_style: { size: 9, padding: 6 }) do
          row(0).font_style = :bold
          row(0).background_color = "EAF4F7"
        end

        pdf.move_down 14
        if invoice.payment_terms_text.present?
          pdf.fill_color "102C43"
          pdf.text "Payment terms", size: 11, style: :bold
          pdf.fill_color "466270"
          pdf.text invoice.payment_terms_text, size: 9
          pdf.move_down 8
        end

        pdf.fill_color "8a5a10"
        pdf.text "No bank details, tax registration numbers or live collection instructions are included on simulated invoices.", size: 8
        pdf.number_pages "Page <page> of <total>", at: [ pdf.bounds.right - 100, 0 ], width: 100, align: :right, size: 8
      end.render
    end
  end
end
