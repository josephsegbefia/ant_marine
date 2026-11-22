# frozen_string_literal: true

require "test_helper"

class BackNavigationTest < ActionDispatch::IntegrationTest
  test "staff client invitation page links back to invitations" do
    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    get new_staff_client_invitation_path
    assert_response :success

    assert_select "a.ant-back-link[href=?]", staff_invitations_path, text: /Back to invitations/
    assert_select "a.ant-back-link svg.ant-back-link__icon"
  end

  test "back link remains when no client organisations are available" do
    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))
    Organization.client.update_all(status: "archived", archived_at: Time.current)

    get new_staff_client_invitation_path
    assert_response :success
    assert_match(/No client organisations available/, response.body)
    assert_select "a.ant-back-link[href=?]", staff_invitations_path
  end

  test "staff invitations links back to staff workspace" do
    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    get staff_invitations_path
    assert_response :success
    assert_select "a.ant-back-link[href=?]", staff_root_path, text: /Back to staff workspace/
  end

  test "client invitations links back to client workspace" do
    sign_in_as(users(:client_owner), membership: memberships(:client_owner_membership))

    get client_invitations_path
    assert_response :success
    assert_select "a.ant-back-link[href=?]", client_root_path, text: /Back to client workspace/
  end

  test "password reset page links back to sign in" do
    get new_password_path
    assert_response :success
    assert_select "a.ant-back-link[href=?]", new_session_path, text: /Back to sign in/
  end

  test "general staff cannot access staff client invitation page" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    get new_staff_client_invitation_path
    assert_redirected_to staff_root_path
  end
end
