# frozen_string_literal: true

module Public
  class ResourcesController < BaseController
    def index
      @resources = PublicResource.published_catalogue.for_ant_marine.ordered
      @seo_title = "Resources — ANT Marine W.A."
      @seo_description = "Approved technical guides and publications from ANT Marine."
    end

    def show
      @resource = PublicResource.published_catalogue.for_ant_marine.find_by(slug: params[:slug])
      raise ActionController::RoutingError, "Not Found" unless @resource

      @seo_title = @resource.public_seo_title
      @seo_description = @resource.public_seo_description
    end
  end
end
