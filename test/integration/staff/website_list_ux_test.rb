# frozen_string_literal: true

require "test_helper"

class Staff::WebsiteListUxTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
  end

  test "services list has single breadcrumb trail and management chrome" do
    get staff_website_services_path
    assert_response :success
    assert_equal 1, response.body.scan('aria-label="Breadcrumb"').size
    assert_includes response.body, "Manage website content"
    assert_includes response.body, "ant-section-tabs"
    assert_includes response.body, "Create service"
    assert_includes response.body, "Continue editing"
    assert_includes response.body, "Draft"
    refute_includes response.body, "marine-surveys ·"
  end

  test "services list shows published guidance and public link when published" do
    get staff_website_services_path
    assert_response :success
    assert_includes response.body, "Visible on the public website"
    assert_includes response.body, "View public page"
    assert_includes response.body, public_service_path(services(:marine_surveys_published).slug)
  end

  test "pages tab navigation and record layout" do
    get staff_website_pages_path
    assert_response :success
    assert_equal 1, response.body.scan('aria-label="Breadcrumb"').size
    assert_includes response.body, "Manage website content"
    assert_includes response.body, "Website pages"
    assert_includes response.body, "ant-content-record"
    assert_includes response.body, "Continue editing"
  end

  test "unauthorized user does not see create service action" do
    sign_in_as users(:staff_only), membership: memberships(:staff_membership)
    get staff_website_services_path
    assert_redirected_to root_path
  end
end
