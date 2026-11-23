# frozen_string_literal: true

module PublicContent
  # Fallback copy when CMS page is not yet published (no fabricated contact details).
  class StaticPageFallback
    attr_reader :page_key

    def initialize(page_key)
      @page_key = page_key
    end

    def publicly_visible?
      false
    end

    def public_title
      {
        "about" => "About ANT Marine",
        "industries" => "Industries we serve",
        "how_we_work" => "How we work",
        "contact" => "Contact us"
      }[page_key] || "ANT Marine W.A."
    end

    def public_summary
      ""
    end

    def public_body
      case page_key
      when "about"
        "ANT Marine W.A. provides marine consulting, surveys, technical support and training. Leadership details and credentials will be added when formally approved."
      when "industries"
        "We work with marine operators, terminals, contractors and public agencies. Industry-specific copy is managed through the staff website tools."
      when "how_we_work"
        "We start with a conversation about your needs, confirm scope, and provide a quotation where appropriate. A preferred date is not a confirmed booking until ANT Marine agrees terms in writing."
      when "contact"
        "Contact channels will appear here once verified. If you already work with ANT Marine, sign in to your workspace for ongoing projects."
      else
        ""
      end
    end

    def public_page_data
      case page_key
      when "contact"
        { "email" => nil, "phone" => nil, "address" => nil, "hours" => nil }
      when "industries"
        {
          "industry_cards" => [
            { "title" => "Oil & gas operators", "description" => "Technical support for marine operations." },
            { "title" => "Port and terminal teams", "description" => "Practical guidance for facilities and projects." },
            { "title" => "Shipowners & operators", "description" => "Surveys and technical management support." },
            { "title" => "Offshore contractors", "description" => "Project coordination and documentation." },
            { "title" => "Classification & inspection partners", "description" => "Structured inspections and reporting." },
            { "title" => "Research and environmental bodies", "description" => "Environmental and compliance reviews." }
          ]
        }
      else
        {}
      end
    end

    def public_seo_title
      "#{public_title} — ANT Marine W.A."
    end

    def public_seo_description
      public_body.truncate(155)
    end
  end
end
