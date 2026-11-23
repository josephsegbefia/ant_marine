# frozen_string_literal: true

module StaffEditorialWorkspaceHelper
  WORKSPACES = {
    "Article" => {
      partial: "article",
      steps: [ "Write article", "Page details", "Review" ],
      path_prefix: "/insights/",
      eyebrow: "Insights",
      heading_new: "Create an insight",
      heading_edit: "Edit insight",
      lede: "Write articles visitors can read on the public website. Save a draft before submitting for review."
    },
    "CaseStudy" => {
      partial: "case_study",
      steps: [ "Overview", "Challenge & approach", "Outcomes", "Review" ],
      path_prefix: "/projects/",
      eyebrow: "Our work",
      heading_new: "Create a project story",
      heading_edit: "Edit project story",
      lede: "Tell an approved client story. Only publish when permission is documented — never copy from confidential projects."
    },
    "TrainingOffering" => {
      partial: "training",
      steps: [ "Course basics", "Learning details", "Review" ],
      path_prefix: "/training/",
      eyebrow: "Training",
      heading_new: "Create a training offering",
      heading_edit: "Edit training offering",
      lede: "Describe training you offer. Do not add prices, dates or registration here."
    },
    "PublicResource" => {
      partial: "public_resource",
      steps: [ "Resource details", "Publication settings", "Review" ],
      path_prefix: "/resources/",
      eyebrow: "Resources",
      heading_new: "Create a public resource",
      heading_edit: "Edit public resource",
      lede: "Catalogue metadata for publications and guides. File downloads remain disabled until release is approved."
    },
    "PublicSitePage" => {
      partial: "site_page",
      steps: [ "Page content", "Review" ],
      path_prefix: nil,
      eyebrow: "Website",
      heading_new: "Edit website page",
      heading_edit: "Edit website page",
      lede: "Update fixed website pages. The page identity does not change."
    }
  }.freeze

  def editorial_workspace_config(record)
    config = WORKSPACES.fetch(record.class.name)
    config.merge(
      step_count: config[:steps].length,
      param_key: record.model_name.param_key,
      return_label: editorial_return_label(record)
    )
  end

  def editorial_return_label(record)
    case record
    when Article then "Return to insights"
    when CaseStudy then "Return to our work"
    when TrainingOffering then "Return to training"
    when PublicResource then "Return to resources"
    when PublicSitePage then "Return to website pages"
    else "Return to list"
    end
  end

  def editorial_public_path(record)
    config = editorial_workspace_config(record)
    return PublicSitePage::PAGE_KEYS.include?(record.page_key) ? "/#{record.page_key}" : "/" if record.is_a?(PublicSitePage)
    return nil unless record.persisted? && record.slug.present? && config[:path_prefix]

    "#{config[:path_prefix]}#{record.slug}"
  end

  def editorial_return_path(record)
    case record
    when Article then staff_website_articles_path
    when CaseStudy then staff_website_case_studies_path
    when TrainingOffering then staff_website_training_offerings_path
    when PublicResource then staff_website_public_resources_path
    when PublicSitePage then staff_website_pages_path
    else staff_website_services_path
    end
  end

  def editorial_training_list(record, attribute)
    items = record.public_send(attribute)
    items = items.is_a?(Array) ? items : []
    items.presence || [ "" ]
  end
end
