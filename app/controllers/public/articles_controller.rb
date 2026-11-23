# frozen_string_literal: true

module Public
  class ArticlesController < BaseController
    def index
      @articles = Article.published_catalogue.for_ant_marine.ordered
      @seo_title = "Insights — ANT Marine W.A."
      @seo_description = "Practical maritime guidance and company updates from ANT Marine."
    end

    def show
      @article = Article.published_catalogue.for_ant_marine.find_by(slug: params[:slug])
      raise ActionController::RoutingError, "Not Found" unless @article

      @seo_title = @article.public_seo_title
      @seo_description = @article.public_seo_description
    end
  end
end
