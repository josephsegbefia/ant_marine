# frozen_string_literal: true

module Commercial
  class QuotePdfRenderer
    def self.render(quote:)
      new(quote:).render
    end

    def initialize(quote:)
      @quote = quote
      @revision = quote.current_revision
    end

    def render
      Prawn::Document.new(page_size: "A4", margin: 48) do |pdf|
        pdf.font "Helvetica"
        render_header(pdf)
        render_status_banner(pdf)
        render_recipient(pdf)
        render_scope(pdf)
        render_pricing(pdf)
        render_terms(pdf)
        render_footer(pdf)
      end.render
    end

    private

      def render_header(pdf)
        pdf.text "ANT Marine W.A.", size: 18, style: :bold, color: "133349"
        pdf.move_down 4
        pdf.text "Quotation #{@quote.reference_number} · Version #{@revision.version_number}", size: 11, color: "5a6f7a"
        pdf.stroke_horizontal_rule
        pdf.move_down 16
      end

      def render_status_banner(pdf)
        label = @quote.status == "draft" ? "DRAFT — NOT A FINAL OFFER" : @quote.status.tr("_", " ").upcase
        pdf.fill_color "e8f4f2"
        pdf.fill_rectangle [ 0, pdf.cursor ], pdf.bounds.width, 28
        pdf.fill_color "133349"
        pdf.indent(12) { pdf.text label, size: 10, style: :bold }
        pdf.move_down 28
      end

      def render_recipient(pdf)
        pdf.text "Prepared for", size: 10, style: :bold
        pdf.text @quote.client_label, size: 12
        prospective = @quote.prospective_client
        %w[contact_name email phone address].each do |key|
          pdf.text prospective[key].to_s, size: 10 if prospective[key].present?
        end
        pdf.move_down 12
      end

      def render_scope(pdf)
        pdf.text @revision.title.to_s, size: 14, style: :bold
        %i[scope_description deliverables exclusions].each do |field|
          value = @revision.public_send(field)
          next if value.blank?

          pdf.move_down 8
          pdf.text field.to_s.humanize, size: 10, style: :bold
          pdf.text value, size: 10, leading: 2
        end
        pdf.move_down 12
      end

      def render_pricing(pdf)
        rows = [ [ "Description", "Qty", "Unit", "Unit price", "Line total" ] ]
        @revision.line_items.order(:position).each do |item|
          rows << [
            item.description,
            item.quantity.to_s("F"),
            item.unit,
            format_money(item.unit_price_cents),
            format_money(item.line_total_cents)
          ]
        end
        rows << [ "", "", "", "Total", format_money(@revision.total_cents) ]

        pdf.table(rows, width: pdf.bounds.width, header: true) do
          row(0).font_style = :bold
          columns(1..4).align = :right
        end
        pdf.move_down 8
        pdf.text "All amounts in #{@revision.currency}. Taxes are not included unless stated separately.", size: 9, color: "5a6f7a"
        pdf.move_down 12
      end

      def render_terms(pdf)
        pdf.text "Validity and terms", size: 10, style: :bold
        pdf.text "Valid until: #{@revision.valid_until || 'To be confirmed'}", size: 10
        pdf.text @revision.payment_terms.to_s, size: 10 if @revision.payment_terms.present?
        pdf.text @revision.commercial_exclusions.to_s, size: 10 if @revision.commercial_exclusions.present?
        pdf.text @revision.additional_conditions.to_s, size: 10 if @revision.additional_conditions.present?
      end

      def render_footer(pdf)
        pdf.move_down 24
        pdf.stroke_horizontal_rule
        pdf.text "ANT Marine W.A. · Marine consulting", size: 8, color: "8197a1", align: :center
      end

      def format_money(cents)
        format("%.2f", cents.to_i / 100.0)
      end
  end
end
