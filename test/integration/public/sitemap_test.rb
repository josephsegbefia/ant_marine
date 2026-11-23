# frozen_string_literal: true

require "test_helper"

class Public::SitemapTest < ActionDispatch::IntegrationTest
  test "sitemap includes published service" do
    get sitemap_path(format: :xml)
    assert_response :success
    assert_includes response.body, "/services/published-surveys"
    assert_not_includes response.body, "/services/marine-surveys"
  end

  test "robots references sitemap" do
    get robots_path(format: :txt)
    assert_response :success
    assert_includes response.body, "Disallow: /staff"
    assert_includes response.body, "sitemap.xml"
  end
end
