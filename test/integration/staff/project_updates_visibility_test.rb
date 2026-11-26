# frozen_string_literal: true

require "test_helper"

class Staff::ProjectUpdatesVisibilityTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @staff = memberships(:ops_manager_membership)
    @owner = memberships(:client_owner_membership)
    @project = build_accepted_project!(staff: @staff, owner: @owner)[:project]
  end

  test "internal update stays off client portal" do
    sign_in_as @staff.user, membership: @staff
    post staff_project_updates_path(@project), params: {
      body: "Internal briefing only",
      visibility: "internal"
    }
    assert_response :redirect

    sign_in_as @owner.user, membership: @owner
    get client_project_path(@project)
    assert_response :success
    assert_no_match(/Internal briefing only/, response.body)
  end

  test "client update appears for owning client" do
    sign_in_as @staff.user, membership: @staff
    post staff_project_updates_path(@project), params: {
      body: "Mobilisation confirmed for next week",
      visibility: "client"
    }
    assert_response :redirect

    sign_in_as @owner.user, membership: @owner
    get client_project_path(@project)
    assert_response :success
    assert_match(/Mobilisation confirmed for next week/, response.body)
  end
end
