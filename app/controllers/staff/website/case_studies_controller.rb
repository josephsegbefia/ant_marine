# frozen_string_literal: true

module Staff
  module Website
    class CaseStudiesController < BaseController
      include StaffWebsiteEditorialController

      self.editorial_record_class = CaseStudy
      self.editorial_section_label = "Our work"

      before_action :set_record, except: %i[index new create]
      before_action :set_hub_meta

      private

        def set_hub_meta
          @hub_active_tab = :our_work
          @hub_section_title = "Our work"
          @hub_section_notice = "Only publish case studies with documented client permission. Never copy from confidential project records."
          @hub_empty_icon = :folder
          @hub_empty_title = "No project stories yet"
          @hub_empty_description = "Add a case study when you have an approved, permission-cleared story to share."
          @hub_new_path = new_staff_website_case_study_path
          @hub_create_label = "New case study"
        end

        def editorial_params
          permitted = params.require(:case_study).permit(
            :title, :summary, :body, :service_category, :industry,
            :client_challenge, :approach, :work_performed, :outcome, :release_basis,
            :seo_title, :seo_description
          )
          permitted.except(:seo_title, :seo_description).merge(
            seo: { "title" => permitted[:seo_title], "description" => permitted[:seo_description] }.compact
          )
        end

        def editorial_show_path(record) = staff_website_case_study_path(record)
        def editorial_index_path = staff_website_case_studies_path
    end
  end
end
