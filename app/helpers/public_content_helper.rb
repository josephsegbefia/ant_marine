# frozen_string_literal: true

module PublicContentHelper
  ALLOWED_TAGS = %w[p br ul ol li strong em a].freeze
  ALLOWED_ATTRIBUTES = %w[href title rel].freeze

  def public_format_text(text)
    return "" if text.blank?

    sanitized = sanitize(text.to_s, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
    simple_format(sanitized, {}, sanitize: false)
  end

  def public_render_rich_text(html)
    return "" if html.blank?

    content_tag(:div, PublicContent::RichText.sanitize_html(html).html_safe, class: "public-rich-text")
  end

  def public_seo_tags(title:, description:, canonical:, og_type: "website")
    safe_title = strip_tags(title.to_s)
    safe_description = strip_tags(description.to_s)
    content_tag(:title, safe_title) +
      tag.meta(name: "description", content: safe_description) +
      tag.link(rel: "canonical", href: canonical) +
      tag.meta(property: "og:title", content: safe_title) +
      tag.meta(property: "og:description", content: safe_description) +
      tag.meta(property: "og:type", content: og_type) +
      tag.meta(property: "og:url", content: canonical) +
      tag.meta(name: "robots", content: "index,follow")
  end
end
