# frozen_string_literal: true

module Reports
  class PdfRenderer
    BRAND = "133349"
    MUTED = "5a6f7a"

    def self.render(report:, version:)
      new(report:, version:).render
    end

    def initialize(report:, version:)
      @report = report
      @version = version
      @content = version.content_json.is_a?(Hash) ? version.content_json : {}
    end

    def render
      Prawn::Fonts::AFM.hide_m17n_warning = true
      Prawn::Document.new(page_size: "A4", margin: [ 48, 48, 60, 48 ], info: document_info) do |pdf|
        pdf.font "Helvetica"
        render_watermark(pdf)
        render_header(pdf)
        render_inspection_summary(pdf)
        render_findings(pdf)
        render_sections(pdf)
        render_footer(pdf)
      end.render
    end

    private

      def safe(value)
        value.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
      end

      def document_info
        { Title: "Report #{@report.reference_number} version #{@version.version_number}", Creator: "ANT Marine W.A." }
      end

      def render_watermark(pdf)
        pdf.repeat(:all) do
          pdf.transparent(0.08) do
            pdf.fill_color "8197a1"
            pdf.rotate(35, origin: [ pdf.bounds.width / 2, pdf.bounds.height / 2 ]) do
              pdf.draw_text "SIMULATED", at: [ pdf.bounds.width / 2 - 180, pdf.bounds.height / 2 - 30 ], size: 90, style: :bold
            end
            pdf.fill_color "000000"
          end
        end
      end

      def render_header(pdf)
        pdf.fill_color BRAND
        pdf.text safe("ANT Marine W.A."), size: 18, style: :bold
        pdf.fill_color "000000"
        pdf.move_down 4
        pdf.text safe(@version.title), size: 14, style: :bold
        pdf.move_down 6
        pdf.fill_color MUTED
        pdf.text safe("Reference #{@report.reference_number} · Version #{@version.version_number}")
        pdf.text safe("Project #{@report.project.reference_number}")
        pdf.fill_color "000000"
        pdf.move_down 14
        pdf.text safe("SIMULATED TECHNICAL REPORT — NOT FOR OFFICIAL USE"), size: 10, style: :bold
        pdf.move_down 10
      end

      def render_inspection_summary(pdf)
        inspection = @content["inspection"]
        return if inspection.blank?

        pdf.text safe("Inspection summary"), size: 12, style: :bold
        pdf.move_down 4
        pdf.text safe("Reference: #{inspection['reference_number']}")
        pdf.text safe("Title: #{inspection['title']}")
        pdf.text safe("Type: #{inspection['inspection_type']}") if inspection["inspection_type"].present?
        pdf.move_down 10
      end

      def render_findings(pdf)
        findings = Array(@content["findings"])
        return if findings.empty?

        pdf.text safe("Findings"), size: 12, style: :bold
        pdf.move_down 4
        findings.each do |finding|
          pdf.text safe("#{finding['reference_number']} — #{finding['title']}"), style: :bold
          pdf.text safe(finding["observation"].to_s), size: 10
          if finding["recommendation"].present?
            pdf.text safe("Recommendation: #{finding['recommendation']}"), size: 10
          end
          pdf.move_down 6
        end
        pdf.move_down 4
      end

      def render_sections(pdf)
        sections = @content["sections"].is_a?(Hash) ? @content["sections"] : {}
        %w[executive_summary conclusions limitations].each do |key|
          body = sections[key].to_s.strip
          next if body.blank?

          pdf.text safe(key.tr("_", " ").capitalize), size: 12, style: :bold
          pdf.move_down 4
          pdf.text safe(body), size: 10
          pdf.move_down 10
        end
      end

      def render_footer(pdf)
        pdf.repeat(:all, dynamic: true) do
          pdf.draw_text safe("Page #{pdf.page_number}"), at: [ pdf.bounds.right - 60, 0 ], size: 8
        end
      end
  end
end
