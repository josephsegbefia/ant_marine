# frozen_string_literal: true

module PublicContent
  module Snapshot
    module_function

    def copy_service!(service)
      service.published_title = service.title
      service.published_summary = service.summary
      service.published_body = service.body
      service.published_audience = service.audience
      service.published_scope_items = service.scope_items
      service.published_process_steps = service.process_steps
      service.published_display_order = service.display_order
      service.published_icon_key = service.icon_key
      service.published_seo = service.seo
      service
    end

    def copy_site_page!(page)
      page.published_title = page.title
      page.published_summary = page.summary
      page.published_body = page.body
      page.published_page_data = page.page_data
      page.published_seo = page.seo
      page
    end

    def copy_article!(article)
      article.published_title = article.title
      article.published_summary = article.summary
      article.published_body = article.body
      article.published_category = article.category
      article.published_seo = article.seo
      article
    end

    def copy_case_study!(study)
      study.published_title = study.title
      study.published_summary = study.summary
      study.published_body = study.body
      study.published_service_category = study.service_category
      study.published_industry = study.industry
      study.published_client_challenge = study.client_challenge
      study.published_approach = study.approach
      study.published_work_performed = study.work_performed
      study.published_outcome = study.outcome
      study.published_seo = study.seo
      study
    end

    def copy_training_offering!(training)
      training.published_title = training.title
      training.published_summary = training.summary
      training.published_body = training.body
      training.published_audience = training.audience
      training.published_learning_objectives = training.learning_objectives
      training.published_topics = training.topics
      training.published_delivery_format = training.delivery_format
      training.published_seo = training.seo
      training
    end

    def copy_public_resource!(resource)
      resource.published_title = resource.title
      resource.published_summary = resource.summary
      resource.published_body = resource.body
      resource.published_resource_category = resource.resource_category
      resource.published_related_content_label = resource.related_content_label
      resource.published_file_release_enabled = resource.file_release_enabled
      resource.published_seo = resource.seo
      resource
    end
  end
end
