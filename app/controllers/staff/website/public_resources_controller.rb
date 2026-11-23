# frozen_string_literal: true

module Staff
  module Website
    class PublicResourcesController < BaseController
      include StaffWebsiteEditorialController

      self.editorial_record_class = PublicResource
      self.editorial_section_label = "Resources"

      before_action :set_record, except: %i[index new create]
      before_action :set_hub_meta

      private

        def set_hub_meta
          @hub_active_tab = :resources
          @hub_section_title = "Resources and publications"
          @hub_section_notice = "File downloads stay disabled until the public storage release gate is approved. Catalogue metadata only."
          @hub_empty_icon = :folder
          @hub_empty_title = "No public resources yet"
          @hub_empty_description = "Add a resource listing when approved publication metadata is ready."
          @hub_new_path = new_staff_website_public_resource_path
          @hub_create_label = "New resource"
        end

        def editorial_params
          permitted = params.require(:public_resource).permit(
            :title, :summary, :body, :resource_category, :related_content_label,
            :seo_title, :seo_description
          )
          {
            title: permitted[:title],
            summary: permitted[:summary],
            body: permitted[:body],
            resource_category: permitted[:resource_category],
            related_content_label: permitted[:related_content_label],
            file_release_enabled: false,
            seo: { "title" => permitted[:seo_title], "description" => permitted[:seo_description] }.compact
          }
        end

        def editorial_show_path(record) = staff_website_public_resource_path(record)
        def editorial_index_path = staff_website_public_resources_path
    end
  end
end
