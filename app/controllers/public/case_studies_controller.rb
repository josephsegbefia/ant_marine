# frozen_string_literal: true

module Public
  class CaseStudiesController < BaseController
    def index
      @case_studies = CaseStudy.published_catalogue.for_ant_marine.ordered
      @seo_title = "Our work — ANT Marine W.A."
      @seo_description = "Approved examples of how ANT Marine supports marine projects."
    end

    def show
      @case_study = CaseStudy.published_catalogue.for_ant_marine.find_by(slug: params[:slug])
      raise ActionController::RoutingError, "Not Found" unless @case_study

      @seo_title = @case_study.public_seo_title
      @seo_description = @case_study.public_seo_description
    end
  end
end
