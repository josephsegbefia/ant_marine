# frozen_string_literal: true

module Staff
  module Website
    class ServicesController < BaseController
      before_action :set_service, except: %i[index new create]

      def index
        assign_website_section_breadcrumb(current: "Services")
        authorize Service
        @services = policy_scope(Service).order(:display_order, :title)
      end

      def show
        authorize @service
        assign_service_editor_breadcrumb(current: @service.title)
      end

      def new
        assign_service_editor_breadcrumb(current: "New service")
        @service = @organization.services.build(
          display_order: next_display_order,
          category: "marine_surveys",
          icon_key: "ship",
          scope_items: [],
          process_steps: []
        )
        @editor_step = editor_step_param
        authorize @service
      end

      def create
        @editor_step = editor_step_param
        @service = @organization.services.build(service_params)
        @service.created_by_membership = Current.membership
        @service.updated_by_membership = Current.membership
        authorize @service
        assign_new_service_defaults!(@service)

        if @service.save
          redirect_after_save(@service, created: true)
        else
          assign_service_editor_breadcrumb(current: "New service")
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        assign_service_editor_breadcrumb(current: @service.title.presence || "Edit service")
        @editor_step = editor_step_param
        authorize @service
      end

      def update
        @editor_step = editor_step_param
        authorize @service
        attributes = service_params
        attributes.delete(:display_order) if attributes[:display_order].nil?
        @service.assign_attributes(attributes)
        @service.updated_by_membership = Current.membership

        if @service.save
          redirect_after_save(@service, created: false)
        else
          assign_service_editor_breadcrumb(current: @service.title.presence || "Edit service")
          render :edit, status: :unprocessable_entity
        end
      end

      def submit_for_review
        authorize @service, :submit_for_review?
        PublicContent::Transition.submit_for_review!(record: @service, membership: Current.membership)
        redirect_to staff_website_service_path(@service), notice: "Service submitted for review."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_service_path(@service), alert: "This service cannot be submitted from its current status."
      end

      def withdraw
        authorize @service, :withdraw?
        PublicContent::Transition.withdraw!(record: @service, membership: Current.membership)
        redirect_to staff_website_service_path(@service), notice: "Moved back to draft."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_service_path(@service), alert: "This service cannot be withdrawn right now."
      end

      def approve
        authorize @service, :approve?
        PublicContent::Transition.approve!(record: @service, membership: Current.membership)
        redirect_to staff_website_service_path(@service), notice: "Service approved. You can publish when ready."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_service_path(@service), alert: "This service cannot be approved right now."
      end

      def publish
        authorize @service, :publish?
        PublicContent::Transition.publish!(record: @service, membership: Current.membership)
        redirect_to staff_website_service_path(@service), notice: "Service published on the public website."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_service_path(@service), alert: "This service cannot be published right now."
      end

      def unpublish
        authorize @service, :unpublish?
        PublicContent::Transition.unpublish!(record: @service, membership: Current.membership)
        redirect_to staff_website_service_path(@service), notice: "Service unpublished."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_service_path(@service), alert: "This service cannot be unpublished right now."
      end

      def archive
        authorize @service, :archive?
        PublicContent::Transition.archive!(record: @service, membership: Current.membership)
        redirect_to staff_website_services_path, notice: "Service archived."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_service_path(@service), alert: "This service cannot be archived right now."
      end

      private

        def set_service
          @service = policy_scope(Service).find(params[:id])
        end

        def service_params
          permitted = params.require(:service).permit(
            :title, :summary, :body, :category, :audience, :icon_key,
            :seo_title, :seo_description,
            :scope_items_text, :process_steps_text,
            scope_items: [],
            process_steps: []
          )
          {
            title: permitted[:title],
            summary: permitted[:summary],
            body: permitted[:body],
            category: permitted[:category],
            audience: permitted[:audience],
            icon_key: permitted[:icon_key],
            scope_items: normalize_list(permitted[:scope_items], permitted[:scope_items_text]),
            process_steps: normalize_list(permitted[:process_steps], permitted[:process_steps_text]),
            seo: {
              "title" => permitted[:seo_title],
              "description" => permitted[:seo_description]
            }.compact
          }
        end

        def normalize_list(values, legacy_text)
          items = Array(values).map { |value| value.to_s.strip }.reject(&:blank?)
          return items if items.any?

          split_lines(legacy_text)
        end

        def editor_step_param
          step = params[:step].presence || params[:editor_step].presence || 1
          step.to_i.clamp(1, 4)
        end

        def redirect_after_save(service, created:)
          commit = params[:commit].to_s
          notice = "Draft saved."
          path = case commit
          when "save_continue"
                   next_step = [ editor_step_param + 1, 4 ].min
                   edit_staff_website_service_path(service, step: next_step)
          when "save_draft"
                   edit_staff_website_service_path(service, step: editor_step_param)
          else
                   created ? edit_staff_website_service_path(service, step: 4) : staff_website_service_path(service)
          end
          redirect_to path, notice: notice
        end

        def split_lines(text)
          text.to_s.lines.map(&:strip).reject(&:blank?)
        end

        def next_display_order
          (policy_scope(Service).maximum(:display_order) || 0) + 1
        end

        def assign_new_service_defaults!(service)
          service.display_order ||= next_display_order
          service.category ||= "marine_surveys"
          service.icon_key ||= "ship"
          service.status ||= "draft"
        end
    end
  end
end
