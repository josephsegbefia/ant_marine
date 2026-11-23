# frozen_string_literal: true

require "test_helper"

class Staff::WebsitePagesTest < ActionDispatch::IntegrationTest
  setup do
    @page = public_site_pages(:about_draft)
  end

  test "super admin can view pages index" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    get staff_website_pages_path
    assert_response :success
  end

  test "pages index empty state" do
    PublicSitePage.delete_all
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    get staff_website_pages_path
    assert_response :success
    assert_includes response.body, "ant-empty-state"
    assert_includes response.body, "No website pages yet"
    assert_includes response.body, "View service pages"
  end

  test "pages index succeeds with existing rows" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    get staff_website_pages_path
    assert_response :success
    assert_includes response.body, "Website"
  end

  test "super admin can edit page" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    get edit_staff_website_page_path(@page)
    assert_response :success
  end

  test "submit for review workflow works" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    post submit_for_review_staff_website_page_path(@page)
    assert_redirected_to staff_website_page_path(@page)
    assert_equal "in_review", @page.reload.status
  end

  test "unknown page id returns not found" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    get staff_website_page_path(id: 9_999_999)
    assert_response :not_found
  end

  test "client cannot access pages index" do
    sign_in_as users(:client_only), membership: memberships(:client_membership)
    get staff_website_pages_path
    assert_redirected_to root_path
  end

  test "anonymous user cannot access pages index" do
    get staff_website_pages_path
    assert_redirected_to new_session_path
  end

  test "general staff denied pages index" do
    sign_in_as users(:staff_only), membership: memberships(:staff_membership)
    get staff_website_pages_path
    assert_redirected_to root_path
  end
end
