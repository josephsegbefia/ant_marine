# frozen_string_literal: true

module Staff
  module Website
    class TrainingOfferingsController < BaseController
      include StaffWebsiteEditorialController

      self.editorial_record_class = TrainingOffering
      self.editorial_section_label = "Training"

      before_action :set_record, except: %i[index new create]
      before_action :set_hub_meta

      private

        def set_hub_meta
          @hub_active_tab = :training
          @hub_section_title = "Training catalogue"
          @hub_section_notice = "List courses only — registration, schedules and certificates are out of scope for this release."
          @hub_empty_icon = :layers
          @hub_empty_title = "No training offerings yet"
          @hub_empty_description = "Create a draft when an approved training description is ready."
          @hub_new_path = new_staff_website_training_offering_path
          @hub_create_label = "New training offering"
        end

        def editorial_params
          permitted = params.require(:training_offering).permit(
            :title, :summary, :body, :audience, :delivery_format,
            :seo_title, :seo_description, learning_objectives: [], topics: []
          )
          {
            title: permitted[:title],
            summary: permitted[:summary],
            body: permitted[:body],
            audience: permitted[:audience],
            delivery_format: permitted[:delivery_format],
            learning_objectives: Array(permitted[:learning_objectives]).map(&:strip).reject(&:blank?),
            topics: Array(permitted[:topics]).map(&:strip).reject(&:blank?),
            seo: { "title" => permitted[:seo_title], "description" => permitted[:seo_description] }.compact
          }
        end

        def editorial_show_path(record) = staff_website_training_offering_path(record)
        def editorial_index_path = staff_website_training_offerings_path
    end
  end
end
