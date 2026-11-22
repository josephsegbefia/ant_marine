require "test_helper"

class PortalAccessTest < ActionDispatch::IntegrationTest
  test "staff member can enter staff context" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    get staff_root_path
    assert_response :success
  end

  test "client-only user cannot enter staff context" do
    sign_in_as(users(:client_only), membership: memberships(:client_membership))

    get staff_root_path
    assert_redirected_to root_path
  end

  test "staff-only user cannot enter client context without client membership" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    get client_root_path
    assert_redirected_to root_path
  end

  test "unauthenticated user cannot access staff or client portals" do
    get staff_root_path
    assert_redirected_to new_session_path

    get client_root_path
    assert_redirected_to new_session_path
  end

  test "multi-organisation user can switch workspaces" do
    user = users(:dual_domain)
    sign_in_as(user, membership: memberships(:dual_staff))

    get staff_root_path
    assert_response :success

    patch workspace_select_path, params: { membership_id: memberships(:dual_client).id }
    assert_redirected_to client_root_path

    get client_root_path
    assert_response :success
  end

  test "cannot forge another users membership" do
    sign_in_as(users(:client_only), membership: memberships(:client_membership))

    patch workspace_select_path, params: { membership_id: memberships(:staff_membership).id }
    assert_redirected_to workspace_selection_path
  end

  test "inactive membership cannot be selected" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    patch workspace_select_path, params: { membership_id: memberships(:suspended_client_membership).id }
    assert_redirected_to workspace_selection_path
  end

  test "signed-out user cannot access workspace selection" do
    get workspace_selection_path
    assert_redirected_to new_session_path
  end
end
