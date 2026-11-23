# frozen_string_literal: true

require "test_helper"

class Staff::WebsiteWorkflowActionsTest < ActionDispatch::IntegrationTest
  setup do
    @service = services(:marine_surveys_draft)
    @page = public_site_pages(:about_draft)
    @admin = users(:super_admin)
    @admin_membership = memberships(:super_admin_membership)
  end

  test "editor step four renders post form for submit for review" do
    sign_in_as @admin, membership: @admin_membership
    get edit_staff_website_service_path(@service, step: 4)
    assert_response :success
    assert_select "form.staff-workflow-action-form[action=?]", submit_for_review_staff_website_service_path(@service) do
      assert_select "[method=post]"
      assert_select "button", text: "Submit for review"
    end
    assert_select "a[href=?]", submit_for_review_staff_website_service_path(@service), count: 0
  end

  test "get submit for review does not change status" do
    sign_in_as @admin, membership: @admin_membership
    get submit_for_review_staff_website_service_path(@service)
    assert_response :not_found
    assert_equal "draft", @service.reload.status
  end

  test "authorized post submit for review transitions and redirects" do
    sign_in_as @admin, membership: @admin_membership
    post submit_for_review_staff_website_service_path(@service)
    assert_redirected_to staff_website_service_path(@service)
    assert_equal "in_review", @service.reload.status
    follow_redirect!
    assert_includes response.body, "Service submitted for review"
  end

  test "unauthorized staff cannot submit for review" do
    sign_in_as users(:staff_only), membership: memberships(:staff_membership)
    post submit_for_review_staff_website_service_path(@service)
    assert_redirected_to root_path
    assert_equal "draft", @service.reload.status
  end

  test "post approve and publish updates snapshot" do
    sign_in_as @admin, membership: @admin_membership
    post submit_for_review_staff_website_service_path(@service)
    post approve_staff_website_service_path(@service)
    assert_equal "approved", @service.reload.status
    prior_published_title = @service.published_title
    post publish_staff_website_service_path(@service)
    @service.reload
    assert_equal "published", @service.status
    assert_equal @service.title, @service.published_title
    refute_equal prior_published_title, @service.published_title if prior_published_title.present?
  end

  test "page show renders post workflow forms" do
    sign_in_as @admin, membership: @admin_membership
    get staff_website_page_path(@page)
    assert_response :success
    assert_select "form.staff-workflow-action-form[action=?][method=post]",
                  submit_for_review_staff_website_page_path(@page)
  end

  test "anonymous cannot post workflow transition" do
    post submit_for_review_staff_website_service_path(@service)
    assert_redirected_to new_session_path
  end
end
