# frozen_string_literal: true

module Public
  class PagesController < BaseController
    PAGE_KEYS = {
      "about" => "about",
      "industries" => "industries",
      "how-we-work" => "how_we_work",
      "contact" => "contact"
    }.freeze

    def show
      page_key = PAGE_KEYS.fetch(params[:page])
      @page = PublicSitePage.published_pages.for_ant_marine.find_by(page_key: page_key)
      if @page.nil?
        @page = PublicContent::StaticPageFallback.new(page_key)
      end
      @seo_title = @page.public_seo_title
      @seo_description = @page.public_seo_description
      render page_key
    end
  end
end
