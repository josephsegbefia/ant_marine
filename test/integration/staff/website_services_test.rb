# frozen_string_literal: true

require "test_helper"

class Staff::WebsiteServicesTest < ActionDispatch::IntegrationTest
  test "super admin can view website services" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    get staff_website_services_path
    assert_response :success
  end

  test "client cannot access staff website" do
    sign_in_as users(:client_only), membership: memberships(:client_membership)
    get staff_website_services_path
    assert_redirected_to root_path
  end

  test "unauthorized publish denied" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    service = services(:marine_surveys_draft)
    post publish_staff_website_service_path(service)
    assert_redirected_to staff_website_service_path(service)
    follow_redirect!
    assert_includes response.body, "cannot be published"
  end
end
