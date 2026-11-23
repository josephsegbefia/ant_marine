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

  def staff_website_breadcrumb_trail(crumbs:, current:)
    render partial: "shared/staff/breadcrumb", locals: { crumbs: crumbs, current: current }
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
    missing << "Page address (URL slug)" if service.slug.blank?
    missing
  end

  def service_public_path_preview(slug)
    return "Save your draft first to confirm the address." if slug.blank?

    "/services/#{slug}"
  end
end
