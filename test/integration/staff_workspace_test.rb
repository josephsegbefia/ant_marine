# frozen_string_literal: true

require "test_helper"

class StaffWorkspaceTest < ActionDispatch::IntegrationTest
  test "super admin staff home renders S01 shell with real team access data" do
    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    get staff_root_path
    assert_response :success

    assert_select ".staff-app-side", count: 1
    assert_select ".staff-app-main", count: 1
    assert_match(/Hello, Super/, response.body)
    assert_select ".staff-org-card", text: /ANT Marine/
    assert_select ".staff-bottom-user", text: /Super Admin/
    assert_select ".staff-bottom-user", text: /Super Administrator/
    assert_match(/1 pending invitation/, response.body)
    assert_no_match(/Jobs in progress/, response.body)
    assert_no_match(/New requests/, response.body)
    assert_select "a.staff-nav-button--active[href=?]", staff_root_path, text: /Overview/
    assert_select "a.staff-nav-button[href=?]", staff_invitations_path, text: /Invitations/
    assert_no_match(/Back to workspaces/, response.body)
  end

  test "dual-domain staff sees workspace back link in header" do
    sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))

    get staff_root_path
    assert_response :success

    assert_select "a.ant-back-link[href=?]", workspace_selection_path, text: /Back to workspaces/
    assert_select "a.staff-org-card__switch[href=?]", workspace_selection_path
  end

  test "single staff membership has no workspace back link" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    get staff_root_path
    assert_response :success

    assert_no_match(/Back to workspaces/, response.body)
    assert_select "a.staff-org-card__switch", count: 0
    assert_no_match(/Team access/, response.body)
    assert_select "a[href=?]", staff_invitations_path, count: 0
  end

  test "client user cannot access staff root" do
    sign_in_as(users(:client_only), membership: memberships(:client_membership))

    get staff_root_path
    assert_redirected_to root_path
  end

  test "invitations index loads inside staff shell" do
    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    get staff_invitations_path
    assert_response :success

    assert_select ".staff-app-side", count: 1
    assert_select "a.staff-nav-button--active", text: /Invitations/
    assert_select "a.ant-back-link[href=?]", staff_root_path, text: /Back to staff workspace/
  end
end
