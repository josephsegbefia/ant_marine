# frozen_string_literal: true

require "test_helper"

class Client::ProjectIsolationTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @staff = memberships(:ops_manager_membership)
    @acme = organizations(:acme_client)
    @other = organizations(:other_client)
    pack = build_accepted_project!(staff: @staff, client_org: @acme, owner: memberships(:client_owner_membership))
    @project = pack[:project]
    @project.update!(internal_notes: "PRIVATE STAFF ONLY")

    other_user = User.create!(
      email: "iso-other-#{SecureRandom.hex(3)}@example.com",
      password: "Secure-password-123",
      status: "active",
      full_name: "Other Client Owner"
    )
    @other_owner = Membership.create!(
      user: other_user,
      organization: @other,
      role_key: "client.org_owner",
      status: "active",
      permission_epoch: 0,
      lock_version: 0,
      accepted_at: Time.current
    )
  end

  test "owning client can view project without internal notes" do
    sign_in_as users(:client_owner), membership: memberships(:client_owner_membership)
    get client_project_path(@project)
    assert_response :success
    assert_match @project.reference_number, response.body
    assert_no_match(/PRIVATE STAFF ONLY/, response.body)
  end

  test "other client organization cannot open project" do
    sign_in_as @other_owner.user, membership: @other_owner
    get client_project_path(@project)
    assert_response :not_found
  end

  test "other client organization project index excludes foreign project" do
    sign_in_as @other_owner.user, membership: @other_owner
    get client_projects_path
    assert_response :success
    assert_no_match @project.reference_number, response.body
  end
end
