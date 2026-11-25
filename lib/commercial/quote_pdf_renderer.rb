# frozen_string_literal: true

module Commercial
  class QuotePdfRenderer
    BRAND = "133349"
    MUTED = "5a6f7a"

    def self.render(quote:, revision: nil)
      new(quote:, revision:).render
    end

    def initialize(quote:, revision: nil)
      @quote = quote
      @revision = revision || quote.current_revision
    end

    def render
      Prawn::Fonts::AFM.hide_m17n_warning = true
      Prawn::Document.new(page_size: "A4", margin: [ 48, 48, 60, 48 ], info: document_info) do |pdf|
        pdf.font "Helvetica"
        render_watermark(pdf) if draft?
        render_header(pdf)
        render_status_banner(pdf)
        render_recipient(pdf)
        render_scope(pdf)
        render_pricing(pdf)
        render_terms(pdf)
        render_page_footer(pdf)
      end.render
    end

    def status_line
      case
      when @quote.status == "withdrawn" then "WITHDRAWN — THIS QUOTATION IS NO LONGER VALID"
      when @revision.revision_status == "superseded" || @quote.current_revision_id != @revision.id
        "SUPERSEDED — REPLACED BY A NEWER VERSION"
      when @quote.status == "issued" then "FINAL VERSION — MARKED ISSUED"
      when @revision.version_frozen? then "APPROVED VERSION — NOT YET SENT TO THE CLIENT"
      when @quote.status == "pending_review" then "DRAFT — AWAITING INTERNAL REVIEW — NOT A FINAL OFFER"
      else "DRAFT — NOT A FINAL OFFER"
      end
    end

    private

      # Built-in PDF fonts only cover Windows-1252; replace anything else instead of failing.
      def safe(value)
        value.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
      end

      def draft?
        !@revision.version_frozen?
      end

      def document_info
        { Title: "Quotation #{@quote.reference_number} version #{@revision.version_number}", Creator: "ANT Marine W.A." }
      end

      def recipient
        @recipient ||= if @revision.version_frozen? && @revision.recipient_lines.present?
          @revision.recipient_lines.to_h.stringify_keys
        else
          {
            "company_name" => @quote.client_label,
            "contact_name" => @quote.prospective_value("contact_name"),
            "email" => @quote.prospective_value("email"),
            "phone" => @quote.prospective_value("phone"),
            "address" => @quote.prospective_value("address")
          }
        end
      end

      def render_watermark(pdf)
        pdf.repeat(:all) do
          pdf.transparent(0.08) do
            pdf.fill_color "8197a1"
            pdf.rotate(35, origin: [ pdf.bounds.width / 2, pdf.bounds.height / 2 ]) do
              pdf.draw_text "DRAFT", at: [ pdf.bounds.width / 2 - 150, pdf.bounds.height / 2 - 30 ], size: 110, style: :bold
            end
            pdf.fill_color "000000"
          end
        end
      end

      def render_header(pdf)
        pdf.text "ANT Marine W.A.", size: 18, style: :bold, color: BRAND
        pdf.move_down 4
        pdf.text "Quotation #{@quote.reference_number} · Version #{@revision.version_number}", size: 11, color: MUTED
        pdf.move_down 6
        pdf.stroke_horizontal_rule
        pdf.move_down 14
      end

      def render_status_banner(pdf)
        pdf.fill_color draft? ? "fdf3e1" : "e8f4f2"
        pdf.fill_rectangle [ 0, pdf.cursor ], pdf.bounds.width, 26
        pdf.fill_color BRAND
        pdf.move_down 8
        pdf.indent(12) { pdf.text status_line, size: 9, style: :bold }
        pdf.move_down 14
        pdf.fill_color "000000"
      end

      def render_recipient(pdf)
        pdf.text "Prepared for", size: 10, style: :bold, color: BRAND
        pdf.text safe(recipient["company_name"].presence || "Client to be confirmed"), size: 12
        %w[contact_name email phone address].each do |key|
          pdf.text safe(recipient[key]), size: 10 if recipient[key].present?
        end
        pdf.move_down 14
      end

      def render_scope(pdf)
        pdf.text safe(@revision.title.presence || "Untitled quotation"), size: 14, style: :bold, color: BRAND
        service_title = recipient["service_title"].presence || (@revision.version_frozen? ? nil : @quote.service&.title)
        pdf.text "Service: #{safe(service_title)}", size: 10, color: MUTED if service_title.present?
        [
          [ :scope_description, "Scope of work" ],
          [ :deliverables, "Deliverables" ],
          [ :exclusions, "Exclusions" ],
          [ :additional_requirements, "Client responsibilities and requirements" ]
        ].each do |field, label|
          value = @revision.public_send(field)
          next if value.blank?

          pdf.move_down 10
          pdf.text label, size: 10, style: :bold
          pdf.text safe(value), size: 10, leading: 2
        end
        pdf.move_down 14
      end

      def render_pricing(pdf)
        currency = @revision.currency
        pdf.text "Pricing", size: 10, style: :bold, color: BRAND
        pdf.move_down 6
        rows = [ [ "Description", "Qty", "Unit", "Unit price", "Line total" ] ]
        items = @revision.line_items.to_a
        items.each do |item|
          rows << [
            safe(item.description.presence || "—"),
            item.quantity_input,
            safe(item.unit),
            Money.display(item.unit_price_cents, currency),
            Money.display(item.line_total_cents, currency)
          ]
        end
        rows << [ { content: "No pricing lines yet", colspan: 5 } ] if items.empty?
        rows << [ { content: "Total", colspan: 4, align: :right, font_style: :bold },
                  { content: Money.display(@revision.total_cents, currency), font_style: :bold } ]

        pdf.table(rows, width: pdf.bounds.width, header: true, cell_style: { size: 9, padding: [ 5, 6 ] },
                        column_widths: { 1 => 50, 2 => 55, 3 => 90, 4 => 95 }) do
          row(0).font_style = :bold
          row(0).background_color = "eef3f5"
          columns(1..4).align = :right
        end
        pdf.move_down 8
        pdf.text "All amounts are in #{currency}. Taxes are not included unless stated separately.", size: 9, color: MUTED
        pdf.move_down 14
      end

      def render_terms(pdf)
        pdf.text "Validity and terms", size: 10, style: :bold, color: BRAND
        valid_until = @revision.valid_until ? @revision.valid_until.strftime("%-d %B %Y") : "To be confirmed"
        pdf.text "Valid until: #{valid_until}", size: 10
        [
          [ :payment_terms, "Payment terms" ],
          [ :commercial_exclusions, "Commercial exclusions" ],
          [ :additional_conditions, "Additional conditions" ]
        ].each do |field, label|
          value = @revision.public_send(field)
          next if value.blank?

          pdf.move_down 8
          pdf.text label, size: 10, style: :bold
          pdf.text safe(value), size: 10, leading: 2
        end
      end

      def render_page_footer(pdf)
        footer = "ANT Marine W.A. · Quotation #{@quote.reference_number} v#{@revision.version_number} · Confidential"
        pdf.repeat(:all, dynamic: true) do
          pdf.bounding_box([ 0, -14 ], width: pdf.bounds.width, height: 20) do
            pdf.text footer, size: 7, color: "8197a1", align: :left
          end
        end
        pdf.number_pages "Page <page> of <total>", at: [ pdf.bounds.right - 120, -14 ], width: 120, align: :right, size: 7, color: "8197a1"
      end
  end
end
