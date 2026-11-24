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
    (service.published_icon_key.presence || service.icon_key.presence || "ship").to_s
  end
end
