# frozen_string_literal: true

module PublicUiHelper
  PRIMARY_NAV = [
    { key: "home", label: "Home", path: :root_path },
    { key: "services", label: "Services", path: :public_services_path },
    { key: "projects", label: "Our work", path: :public_projects_path },
    { key: "training", label: "Training", path: :public_training_path },
    { key: "insights", label: "Insights", path: :public_insights_path },
    { key: "contact", label: "Contact", path: :contact_path }
  ].freeze

  SECONDARY_NAV = [
    { key: "resources", label: "Resources", path: :public_resources_path },
    { key: "about", label: "About", path: :about_path },
    { key: "industries", label: "Industries", path: :industries_path },
    { key: "how_we_work", label: "How we work", path: :how_we_work_path }
  ].freeze

  def public_primary_nav_links
    PRIMARY_NAV
  end

  def public_secondary_nav_links
    SECONDARY_NAV
  end

  def public_nav_path(link)
    send(link[:path])
  end

  def public_service_category_label(service)
    category = service.category.to_s
    StaffWebsiteHelper::SERVICE_CATEGORY_OPTIONS[category] || category.humanize
  end

  def public_service_icon_key(service)
    PublicContent::IconCatalog.resolve(service.published_icon_key.presence || service.icon_key)
  end

  INDUSTRY_ICONS = %w[ship brief layers wrench shield leaf anchor globe].freeze

  def public_industry_icon(index)
    INDUSTRY_ICONS[index % INDUSTRY_ICONS.size]
  end

  def public_case_study_service_area(case_study)
    StaffWebsiteHelper::SERVICE_CATEGORY_OPTIONS[case_study.published_service_category.to_s]
  end

  def public_case_study_outcome_excerpt(case_study)
    text = strip_tags(case_study.published_outcome.to_s).squish
    truncate(text, length: 200, separator: " ") if text.present?
  end

  def public_service_card_summary(service)
    summary = service.public_summary.to_s.strip
    return summary if summary.length >= 48

    items = service.public_scope_items
    if items.size >= 2
      "#{items.first} and #{items.second}."
    elsif items.size == 1
      "#{summary.presence || 'Practical support'} — #{items.first}."
    else
      summary.presence || "Independent marine support for vessels, facilities and technical projects."
    end
  end
end
