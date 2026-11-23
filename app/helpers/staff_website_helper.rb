# frozen_string_literal: true

module StaffWebsiteHelper
  SERVICE_CATEGORY_OPTIONS = {
    "marine_surveys" => "Marine surveys",
    "project_support" => "Project support",
    "environmental_safety" => "Environmental & safety checks",
    "naval_design" => "Naval design & modifications",
    "technical_reports" => "Technical reports",
    "training" => "Training"
  }.freeze

  ICON_KEY_OPTIONS = {
    "ship" => "Ship",
    "brief" => "Briefcase",
    "leaf" => "Leaf",
    "wrench" => "Wrench",
    "file" => "Document",
    "book" => "Book"
  }.freeze

  PAGE_KEY_LABELS = {
    "homepage" => "Homepage",
    "about" => "About the company",
    "industries" => "Industries served",
    "how_we_work" => "How we work",
    "contact" => "Contact information"
  }.freeze

  def public_content_status_label(status)
    {
      "draft" => "Draft",
      "in_review" => "In review",
      "approved" => "Approved",
      "published" => "Published",
      "archived" => "Archived"
    }[status.to_s] || status.to_s.humanize
  end

  def public_content_status_badge_class(status)
    case status.to_s
    when "draft" then "ant-badge--warn"
    when "in_review" then "ant-badge--blue"
    when "approved" then "ant-badge--teal"
    when "published" then "ant-badge--good"
    else "ant-badge--muted"
    end
  end

  def public_content_list_guidance(status)
    case status.to_s
    when "draft" then "Not visible to visitors yet."
    when "in_review" then "Waiting for content approval."
    when "approved" then "Ready to publish when you are satisfied with the content."
    when "published" then "Visible on the public website."
    when "archived" then "Hidden from the public website."
    else ""
    end
  end

  def service_record_description(service)
    service.summary.presence || SERVICE_CATEGORY_OPTIONS[service.category] || "Service page draft"
  end

  def service_record_meta(service)
    return nil if service.updated_at.blank?

    "Last saved #{l(service.updated_at, format: :short)}"
  end

  def service_record_icon(service)
    case service.icon_key
    when "brief" then "folder"
    when "leaf" then "globe"
    when "book" then "layers"
    else "layers"
    end
  end

  def service_list_primary_action(service)
    return nil unless policy(service).show?

    if policy(service).update?
      case service.status
      when "draft"
        { label: "Continue editing", path: edit_staff_website_service_path(service) }
      when "in_review", "approved", "archived"
        { label: "Review content", path: staff_website_service_path(service) }
      when "published"
        { label: "Continue editing", path: edit_staff_website_service_path(service) }
      else
        { label: "Open", path: staff_website_service_path(service) }
      end
    else
      { label: "View", path: staff_website_service_path(service) }
    end
  end

  def service_list_secondary_action(service)
    return nil unless service.published? && service.slug.present?

    { label: "View public page", path: public_service_path(service.slug) }
  end

  def public_site_page_label(page)
    PAGE_KEY_LABELS[page.page_key] || page.page_key.humanize
  end

  def public_site_page_description(page)
    page.summary.presence || public_site_page_label(page)
  end

  def public_site_page_list_primary_action(page)
    return nil unless policy(page).show?

    if policy(page).update?
      case page.status
      when "draft", "published"
        { label: "Continue editing", path: edit_staff_website_page_path(page) }
      when "in_review", "approved", "archived"
        { label: "Review content", path: staff_website_page_path(page) }
      else
        { label: "Open", path: staff_website_page_path(page) }
      end
    else
      { label: "View", path: staff_website_page_path(page) }
    end
  end

  def public_site_page_public_path(page)
    return nil unless page.published?

    case page.page_key
    when "homepage" then root_path
    when "about" then about_path
    when "industries" then industries_path
    when "how_we_work" then how_we_work_path
    when "contact" then contact_path
    else nil
    end
  end

  def public_site_page_list_secondary_action(page)
    path = public_site_page_public_path(page)
    return nil if path.blank?

    { label: "View public page", path: path }
  end

  def service_editor_list(service, attribute)
    value = service.public_send(attribute)
    return value if value.is_a?(Array)
    return JSON.parse(value) if value.is_a?(String) && value.start_with?("[")

    []
  rescue JSON::ParserError
    []
  end

  def service_category_options
    SERVICE_CATEGORY_OPTIONS.map { |key, label| [ label, key ] }
  end

  def service_icon_options
    ICON_KEY_OPTIONS.map { |key, label| [ label, key ] }
  end

  def service_status_guidance(service)
    case service.status
    when "draft"
      "Draft — only your team can see this. Submit it for review when the content is ready."
    when "in_review"
      "In review — waiting for someone with publish permission to approve."
    when "approved"
      "Approved — ready to publish when you are satisfied with the content."
    when "published"
      "Published — visitors see the last published version. Edits here stay private until you submit, approve, and publish again."
    when "archived"
      "Archived — not shown on the public website."
    else
      service.status.humanize
    end
  end

  def service_editor_missing_items(service)
    missing = []
    missing << "Service name" if service.title.blank?
    missing << "Short description" if service.summary.blank?
    missing << "Full explanation" if service.body.blank?
    missing << "Intended audience" if service.audience.blank?
    missing << "At least one scope item" if service_editor_list(service, :scope_items).empty?
    missing << "At least one process step" if service_editor_list(service, :process_steps).empty?
    missing << "Service category" if service.category.blank?
    missing
  end

  def service_public_path_preview(slug)
    return "Save your draft first to confirm the address." if slug.blank?

    "/services/#{slug}"
  end

  def website_workflow_button(label, url, variant: :primary, confirm: nil)
    classes = variant == :outline ? "ant-btn-outline ant-btn-outline--compact" : "ant-btn-primary ant-btn-primary--compact"
    options = {
      method: :post,
      class: classes,
      form: { class: "staff-workflow-action-form" }
    }
    options[:form][:data] = { turbo_confirm: confirm } if confirm.present?
    button_to(label, url, **options)
  end
end
