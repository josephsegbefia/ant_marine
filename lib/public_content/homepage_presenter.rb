# frozen_string_literal: true

module PublicContent
  class HomepagePresenter
    DEFAULTS = {
      eyebrow: "Practical maritime expertise · Ghana & West Africa",
      title: "Marine expertise for projects that matter.",
      lede: "From vessel surveys and engineering advice to offshore projects and training, we help you move forward with confidence.",
      primary_cta_label: "Get in touch",
      primary_cta_path: "/contact",
      secondary_cta_label: "Explore services",
      secondary_cta_path: "/services"
    }.freeze

    PROCESS_STEPS = [
      { title: "Tell us what you need",
        description: "Share a few details about your vessel, facility or project." },
      { title: "Agree the scope",
        description: "We confirm what is needed and prepare a clear quotation where appropriate." },
      { title: "Work goes ahead",
        description: "Dates are confirmed once we have agreed the terms with you in writing." },
      { title: "Receive a reviewed report",
        description: "Every report is checked and approved before it is shared with you." }
    ].freeze

    def initialize(page)
      @page = page
    end

    def data
      published = @page&.publicly_visible? ? @page.public_page_data : {}
      DEFAULTS.merge(published.symbolize_keys)
    end

    def process_steps
      PROCESS_STEPS
    end

    def seo_title
      @page&.public_seo_title.presence || "ANT Marine W.A. — Marine expertise"
    end

    def seo_description
      @page&.public_seo_description.presence || DEFAULTS[:lede]
    end
  end
end
