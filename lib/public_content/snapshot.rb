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
  end
end
