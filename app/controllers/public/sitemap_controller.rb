# frozen_string_literal: true

module Public
  class SitemapController < BaseController
    def show
      host = request.base_url
      render xml: PublicContent::SitemapBuilder.call(host: host)
    end
  end
end
