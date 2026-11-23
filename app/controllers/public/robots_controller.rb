# frozen_string_literal: true

module Public
  class RobotsController < BaseController
    def show
      render plain: robots_body, content_type: "text/plain"
    end

    private

      def robots_body
        <<~TXT
          User-agent: *
          Disallow: /staff
          Disallow: /client
          Disallow: /session
          Disallow: /workspace
          Allow: /

          Sitemap: #{request.base_url}/sitemap.xml
        TXT
      end
  end
end
