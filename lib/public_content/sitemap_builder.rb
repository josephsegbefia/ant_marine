# frozen_string_literal: true

module PublicContent
  class SitemapBuilder
    STATIC_PATHS = %w[/ /services /about /industries /how-we-work /contact].freeze

    def self.call(host:)
      new(host: host).to_xml
    end

    def initialize(host:)
      @host = host.to_s.chomp("/")
    end

    def to_xml
      urls = STATIC_PATHS.map { |path| url_node(path) }
      Service.published_catalogue.for_ant_marine.find_each do |service|
        urls << url_node("/services/#{service.slug}", updated_at: service.updated_at)
      end

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        #{urls.join("\n")}
        </urlset>
      XML
    end

    private

      def url_node(path, updated_at: Time.current)
        loc = "#{@host}#{path}"
        lastmod = updated_at.utc.iso8601
        "  <url><loc>#{ERB::Util.html_escape(loc)}</loc><lastmod>#{lastmod}</lastmod></url>"
      end
  end
end
