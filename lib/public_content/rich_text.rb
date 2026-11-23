# frozen_string_literal: true

module PublicContent
  module RichText
    ALLOWED_TAGS = %w[p br ul ol li strong em a u del pre code h1 h2 h3 blockquote div].freeze
    ALLOWED_ATTRIBUTES = %w[href title rel class].freeze
    UNSAFE_HREF = /href\s*=\s*["']?\s*javascript:/i
  ATTACHMENT_MARKERS = /action-text-attachment|data-trix-attachment|data-trix-mutable="true"[^>]*class="[^"]*attachment/

    module_function

    def plain_to_html(text)
      return "" if text.blank?

      text.to_s.split(/\n\n+/).map do |paragraph|
        escaped = ERB::Util.html_escape(paragraph.strip)
        escaped = escaped.gsub(/\n/, "<br>")
        "<p>#{escaped}</p>"
      end.join
    end

    def snapshot_html(rich_text)
      return "" if rich_text.blank?

      sanitize_html(rich_text.body.to_s)
    end

    def sanitize_html(html)
      return "" if html.blank?

      stripped = strip_attachments(html)
      sanitized = ActionController::Base.helpers.sanitize(
        stripped,
        tags: ALLOWED_TAGS,
        attributes: ALLOWED_ATTRIBUTES
      )
      sanitized.gsub(UNSAFE_HREF, 'href="#"')
    end

    def strip_attachments(html)
      html.to_s
          .gsub(/<action-text-attachment\b[^>]*>.*?<\/action-text-attachment>/m, "")
          .gsub(/<action-text-attachment\b[^>]*\/?>/, "")
          .gsub(/<figure[^>]*data-trix-attachment[^>]*>.*?<\/figure>/m, "")
    end

    def attachments_present?(html)
      html.to_s.match?(ATTACHMENT_MARKERS)
    end

    def scrub!(rich_text)
      return if rich_text.blank?

      body = rich_text.body.to_s
      return unless attachments_present?(body)

      rich_text.body = strip_attachments(body)
    end
  end
end
