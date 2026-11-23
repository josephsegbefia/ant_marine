# frozen_string_literal: true

module Staff
  module Website
    class PagesController < BaseController
      before_action :set_page, only: %i[
        show edit update
        submit_for_review withdraw approve publish unpublish archive
      ]

      def index
        assign_website_section_breadcrumb(current: "Website pages")
        authorize PublicSitePage
        @pages = policy_scope(PublicSitePage).order(:page_key)
      end

      def show
        authorize @page
        assign_staff_breadcrumb(
          crumbs: [
            { label: "Website", path: staff_website_services_path },
            { label: "Website pages", path: staff_website_pages_path }
          ],
          current: @page.title
        )
      end

      def edit
        authorize @page
        assign_staff_breadcrumb(
          crumbs: [
            { label: "Website", path: staff_website_services_path },
            { label: "Website pages", path: staff_website_pages_path }
          ],
          current: @page.title
        )
      end

      def update
        authorize @page
        @page.assign_attributes(page_params)
        @page.updated_by_membership = Current.membership

        if @page.save
          redirect_to staff_website_page_path(@page), notice: "Page draft saved."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def submit_for_review
        authorize @page, :submit_for_review?
        PublicContent::Transition.submit_for_review!(record: @page, membership: Current.membership)
        redirect_to staff_website_page_path(@page), notice: "Page submitted for review."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_page_path(@page), alert: "This page cannot be submitted from its current status."
      end

      def withdraw
        authorize @page, :withdraw?
        PublicContent::Transition.withdraw!(record: @page, membership: Current.membership)
        redirect_to staff_website_page_path(@page), notice: "Moved back to draft."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_page_path(@page), alert: "This page cannot be withdrawn right now."
      end

      def approve
        authorize @page, :approve?
        PublicContent::Transition.approve!(record: @page, membership: Current.membership)
        redirect_to staff_website_page_path(@page), notice: "Page approved."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_page_path(@page), alert: "This page cannot be approved right now."
      end

      def publish
        authorize @page, :publish?
        PublicContent::Transition.publish!(record: @page, membership: Current.membership)
        redirect_to staff_website_page_path(@page), notice: "Page published."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_page_path(@page), alert: "This page cannot be published right now."
      end

      def unpublish
        authorize @page, :unpublish?
        PublicContent::Transition.unpublish!(record: @page, membership: Current.membership)
        redirect_to staff_website_page_path(@page), notice: "Page unpublished."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_page_path(@page), alert: "This page cannot be unpublished right now."
      end

      def archive
        authorize @page, :archive?
        PublicContent::Transition.archive!(record: @page, membership: Current.membership)
        redirect_to staff_website_pages_path, notice: "Page archived."
      rescue PublicContent::Transition::InvalidTransition
        redirect_to staff_website_page_path(@page), alert: "This page cannot be archived right now."
      end

      private

        def set_page
          @page = policy_scope(PublicSitePage).find(params[:id])
        end

        def page_params
          permitted = params.require(:public_site_page).permit(
            :title, :summary, :body, :seo_title, :seo_description,
            *page_data_fields
          )
          data = extract_page_data(permitted)
          {
            title: permitted[:title],
            summary: permitted[:summary],
            body: permitted[:body],
            page_data: @page.page_data.merge(data),
            seo: {
              "title" => permitted[:seo_title],
              "description" => permitted[:seo_description]
            }.compact
          }
        end

        def page_data_fields
          case @page.page_key
          when "homepage"
            %i[eyebrow hero_title hero_lede primary_cta_label primary_cta_path secondary_cta_label secondary_cta_path].freeze
          when "contact"
            %i[contact_email contact_phone contact_address contact_hours]
          else
            []
          end
        end

        def extract_page_data(permitted)
          case @page.page_key
          when "homepage"
            {
              "eyebrow" => permitted[:eyebrow],
              "title" => permitted[:hero_title],
              "lede" => permitted[:hero_lede],
              "primary_cta_label" => permitted[:primary_cta_label],
              "primary_cta_path" => permitted[:primary_cta_path],
              "secondary_cta_label" => permitted[:secondary_cta_label],
              "secondary_cta_path" => permitted[:secondary_cta_path]
            }.compact
          when "contact"
            {
              "email" => permitted[:contact_email],
              "phone" => permitted[:contact_phone],
              "address" => permitted[:contact_address],
              "hours" => permitted[:contact_hours]
            }.compact
          else
            {}
          end
        end
    end
  end
end
