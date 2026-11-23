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

  test "super admin can open new service form" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    get new_staff_website_service_path
    assert_response :success
    assert_includes response.body, "Create a service"
    assert_includes response.body, "staff-editor-stepper"
    assert_includes response.body, "Website"
    assert_includes response.body, "Services"
  end

  test "super admin can create draft service" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)

    assert_difference "Service.count", 1 do
      post staff_website_services_path, params: {
        service: {
          title: "Harbour support",
          slug: "harbour-support",
          summary: "Harbour attendance.",
          body: "Details pending editorial review.",
          category: "project_support",
          icon_key: "brief",
          scope_items: [ "Harbour attendance" ],
          process_steps: [ "Review request" ]
        },
        commit: "save_draft",
        editor_step: 1
      }
    end

    service = Service.find_by!(slug: "harbour-support")
    assert_equal "draft", service.status
    assert_redirected_to edit_staff_website_service_path(service, step: 1)
  end

  test "general staff denied new service" do
    sign_in_as users(:staff_only), membership: memberships(:staff_membership)
    get new_staff_website_service_path
    assert_redirected_to root_path
    assert_equal "You do not have permission to perform that action.", flash[:alert]
  end

  test "general staff denied create service" do
    sign_in_as users(:staff_only), membership: memberships(:staff_membership)

    assert_no_difference "Service.count" do
      post staff_website_services_path, params: {
        service: { title: "Blocked", slug: "blocked-service" }
      }
    end

    assert_redirected_to root_path
  end

  test "client user denied staff website new" do
    sign_in_as users(:client_only), membership: memberships(:client_membership)
    get new_staff_website_service_path
    assert_redirected_to root_path
  end

  test "anonymous user denied new service" do
    get new_staff_website_service_path
    assert_redirected_to new_session_path
  end

  test "submit for review workflow still works" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    service = services(:marine_surveys_draft)

    post submit_for_review_staff_website_service_path(service)
    assert_redirected_to staff_website_service_path(service)
    assert_equal "in_review", service.reload.status
  end
end
