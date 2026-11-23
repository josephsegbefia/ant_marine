# frozen_string_literal: true

require "test_helper"

class Public::F401bContentTest < ActionDispatch::IntegrationTest
  test "insights index and published article" do
    get public_insights_path
    assert_response :success
    assert_includes response.body, "Published insight"
    get public_insight_path("published-insight")
    assert_response :success
    get public_insight_path("draft-insight")
    assert_response :not_found
  end

  test "staff articles index for super admin" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    get staff_website_articles_path
    assert_response :success
    assert_includes response.body, "Insights and articles"
  end

  test "client denied staff articles" do
    sign_in_as users(:client_only), membership: memberships(:client_membership)
    get staff_website_articles_path
    assert_redirected_to root_path
  end
end
