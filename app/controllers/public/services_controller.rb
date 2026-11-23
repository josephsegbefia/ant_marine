# frozen_string_literal: true

module Public
  class ServicesController < BaseController
    def index
      @services = Service.published_catalogue.for_ant_marine.order(:published_display_order, :display_order, :title)
      @seo_title = "Our services — ANT Marine W.A."
      @seo_description = "Practical marine support for vessels, facilities and offshore projects in Ghana and West Africa."
    end

    def show
      @service = Service.published_catalogue.for_ant_marine.find_by(slug: params[:slug])
      raise ActionController::RoutingError, "Not Found" unless @service

      @seo_title = @service.public_seo_title
      @seo_description = @service.public_seo_description
    end
  end
end
