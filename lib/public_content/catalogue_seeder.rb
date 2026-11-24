# frozen_string_literal: true

module PublicContent
  class CatalogueSeeder
    SERVICE_DEFINITIONS = [
      {
        slug: "marine-surveys",
        title: "Marine surveys",
        summary: "Surveys, inspections and checks for vessels, equipment and offshore work.",
        category: "marine_surveys",
        icon_key: "clipboard",
        display_order: 1,
        audience: "Shipowners, vessel managers, offshore contractors and insurers",
        body: "Independent checks and technical assessments for vessels, marine equipment and offshore projects.",
        scope_items: [
          "Marine warranty surveys and inspections",
          "Hull and machinery damage assessments",
          "Pre-purchase vessel inspections",
          "On-hire and off-hire inspections",
          "Incident investigations",
          "Project cargo and offshore installation surveys"
        ],
        process_steps: [
          "Tell us about the work. We will review your request, confirm any missing details, and provide a quotation where appropriate."
        ]
      },
      {
        slug: "project-support",
        title: "Project support",
        summary: "Practical planning, drydock and technical support from start to finish.",
        category: "project_support",
        icon_key: "layers",
        display_order: 2,
        audience: "Vessel operators, ports, marine contractors and project owners",
        body: "Experienced support for safe, organised and well-documented marine projects.",
        scope_items: [
          "Ship-in-service inspections",
          "Drydock project support and repair attendance",
          "Sea trials and technical supervision",
          "Marine construction and project coordination",
          "Technical assurance and project reviews"
        ],
        process_steps: [
          "We agree scope and timing with your team before fieldwork or attendance begins."
        ]
      },
      {
        slug: "environmental-safety",
        title: "Environmental & safety checks",
        summary: "Environmental reviews, internal audits and compliance support.",
        category: "environmental_safety",
        icon_key: "leaf",
        display_order: 3,
        audience: "Marine operators, terminals, project teams and public agencies",
        body: "Practical reviews to help teams understand requirements and improve compliance.",
        scope_items: [
          "Marine environmental assessments",
          "Internal ISM, MLC and ISPS audits",
          "Environmental compliance reviews",
          "Biodiversity and conservation considerations",
          "Advice on relevant marine requirements"
        ],
        process_steps: [
          "We clarify regulatory context and site needs before scheduling reviews."
        ]
      },
      {
        slug: "naval-design-modifications",
        title: "Naval design & modifications",
        summary: "Design support, upgrades and modifications for marine assets.",
        category: "naval_design",
        icon_key: "wrench",
        display_order: 4,
        audience: "Shipowners, refit teams, operators and project developers",
        body: "Engineering and technical support for changes to ships and marine systems.",
        scope_items: [
          "Naval architectural design support",
          "System retrofit advice",
          "Vessel modifications and upgrades",
          "Installation and design reviews",
          "Technical compliance checks"
        ],
        process_steps: [
          "We review design objectives and constraints before recommending next steps."
        ]
      },
      {
        slug: "technical-reports",
        title: "Technical reports",
        summary: "Clear technical findings, records and supporting documents.",
        category: "technical_reports",
        icon_key: "file",
        display_order: 5,
        audience: "Ship operators, insurers, contractors and project managers",
        body: "Clear, structured documentation to support decisions and project records.",
        scope_items: [
          "Marine inspection reports",
          "Technical assessment and condition reports",
          "Inspection findings and recommendations",
          "Project records and supporting documentation",
          "Documentation reviews"
        ],
        process_steps: [
          "Draft reports follow internal review before any client release in live operations."
        ]
      },
      {
        slug: "training",
        title: "Training",
        summary: "Focused learning for marine teams and organisations.",
        category: "training",
        icon_key: "book",
        display_order: 6,
        audience: "Marine professionals, organisations and training partners",
        body: "Practical learning designed around the needs of marine teams and organisations.",
        scope_items: [
          "Team workshops and technical sessions",
          "Safety and compliance awareness",
          "Custom training for organisations",
          "Training enquiries and registration",
          "Technical knowledge sharing"
        ],
        process_steps: [
          "Training dates and fees are confirmed before registration—not assumed from an enquiry alone."
        ]
      }
    ].freeze

    def self.seed!
      org = Organization.ant_marine!
      seed_services!(org)
      seed_pages!(org)
    end

    def self.seed_services!(org)
      SERVICE_DEFINITIONS.each do |attrs|
        service = Service.find_or_initialize_by(organization: org, slug: attrs[:slug])
        next unless service.new_record?

        service.assign_attributes(attrs.merge(status: "draft"))
        service.save!
      end
    end

    def self.seed_pages!(org)
      PublicSitePage::PAGE_KEYS.each do |key|
        page = PublicSitePage.find_or_initialize_by(organization: org, page_key: key)
        next unless page.new_record?

        page.assign_attributes(default_page_attrs(key))
        page.status = "draft"
        page.save!
      end
    end

    def self.default_page_attrs(key)
      case key
      when "homepage"
        {
          title: "Homepage",
          summary: "Public entry point",
          page_data: PublicContent::HomepagePresenter::DEFAULTS.stringify_keys
        }
      when "about"
        {
          title: "About ANT Marine",
          body: "We support marine organisations with inspections, project guidance, environmental reviews, naval design services and clear reporting. Leadership biographies and formal credentials require separate approval before publication."
        }
      when "industries"
        {
          title: "Industries we serve",
          page_data: PublicContent::StaticPageFallback.new("industries").public_page_data
        }
      when "how_we_work"
        {
          title: "How we work",
          body: PublicContent::StaticPageFallback.new("how_we_work").public_body
        }
      when "contact"
        {
          title: "Contact",
          body: "Verified contact details are managed here. Nothing is shown publicly until approved.",
          page_data: { "email" => nil, "phone" => nil, "address" => nil, "hours" => nil }
        }
      else
        { title: key.humanize }
      end
    end
  end
end
