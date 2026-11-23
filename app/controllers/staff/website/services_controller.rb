# frozen_string_literal: true

module Staff
  module Website
    class ServicesController < BaseController
      before_action :set_service, except: %i[index new create]

      def index
        authorize Service
        @services = policy_scope(Service).order(:display_order, :title)
      end

      def show
        authorize @service
      end

      def new
        @service = @organization.services.build(display_order: next_display_order)
        authorize @service
      end

      def create
        @service = @organization.services.build(service_params)
        @service.display_order = service_params[:display_order].presence || next_display_order
        @service.created_by_membership = Current.membership
        @service.updated_by_membership = Current.membership
        authorize @service
        mirror_draft_json_defaults!(@service)

        if @service.save
          redirect_to staff_website_service_path(@service), notice: "Service draft saved."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        authorize @service
      end

      def update
        authorize @service
        @service.assign_attributes(service_params)
        @service.updated_by_membership = Current.membership

        if @service.save
          redirect_to staff_website_service_path(@service), notice: "Service draft saved."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def submit_for_review
        authorize @service, :submit_for_review?
        PublicContent::Transition.submit_for_review!(record: @service, membership: Current.membership)
        redirect_to staff_website_service_path(@service), notice: "Submitted for review."
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
        redirect_to staff_website_service_path(@service), notice: "Service approved."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_service_path(@service), alert: "This service cannot be approved right now."
      end

      def publish
        authorize @service, :publish?
        PublicContent::Transition.publish!(record: @service, membership: Current.membership)
        redirect_to staff_website_service_path(@service), notice: "Service published."
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
            :title, :slug, :summary, :body, :category, :audience, :display_order, :icon_key,
            :seo_title, :seo_description,
            :scope_items_text, :process_steps_text
          )
          {
            title: permitted[:title],
            slug: permitted[:slug],
            summary: permitted[:summary],
            body: permitted[:body],
            category: permitted[:category],
            audience: permitted[:audience],
            display_order: permitted[:display_order],
            icon_key: permitted[:icon_key],
            scope_items: split_lines(permitted[:scope_items_text]),
            process_steps: split_lines(permitted[:process_steps_text]),
            seo: {
              "title" => permitted[:seo_title],
              "description" => permitted[:seo_description]
            }.compact
          }
        end

        def split_lines(text)
          text.to_s.lines.map(&:strip).reject(&:blank?)
        end

        def next_display_order
          (policy_scope(Service).maximum(:display_order) || 0) + 1
        end

        def mirror_draft_json_defaults!(service)
          service.published_scope_items = service.scope_items if service.published_scope_items.blank?
          service.published_process_steps = service.process_steps if service.published_process_steps.blank?
          service.published_seo = service.seo if service.published_seo.blank?
        end
    end
  end
end
