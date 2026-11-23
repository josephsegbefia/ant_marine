# frozen_string_literal: true

module Public
  class TrainingOfferingsController < BaseController
    def index
      @training_offerings = TrainingOffering.published_catalogue.for_ant_marine.ordered
      @seo_title = "Training — ANT Marine W.A."
      @seo_description = "Training and workshops from ANT Marine."
    end

    def show
      @training = TrainingOffering.published_catalogue.for_ant_marine.find_by(slug: params[:slug])
      raise ActionController::RoutingError, "Not Found" unless @training

      @seo_title = @training.public_seo_title
      @seo_description = @training.public_seo_description
    end
  end
end
