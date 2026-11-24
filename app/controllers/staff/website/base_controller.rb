# frozen_string_literal: true

module Staff
  module Website
    class BaseController < Staff::BaseController
      before_action :set_ant_marine_organization

      private

        def set_ant_marine_organization
          @organization = Organization.ant_marine!
        end

        def assign_website_section_breadcrumb(current:)
          assign_staff_breadcrumb(
            crumbs: [ { label: "Website", path: staff_website_services_path } ],
            current: current
          )
        end

        def assign_service_editor_breadcrumb(current:)
          assign_content_editor_breadcrumb(
            section_label: "Services",
            section_path: staff_website_services_path,
            current: current
          )
        end

        def assign_content_editor_breadcrumb(section_label:, section_path:, current:)
          assign_staff_breadcrumb(
            crumbs: [
              { label: "Website", path: staff_website_services_path },
              { label: section_label, path: section_path }
            ],
            current: current
          )
        end
    end
  end
end
