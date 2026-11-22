# frozen_string_literal: true

require "test_helper"

class StaffInvitationsTest < ActionDispatch::IntegrationTest
  test "super admin can create staff invitation" do
    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    assert_difference -> { Invitation.count }, 1 do
      post staff_invitations_path, params: { email: "colleague@example.com", role_key: "staff.general_staff" }
    end
    assert_redirected_to staff_invitations_path
  end

  test "general staff cannot access invitation management" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    get staff_invitations_path
    assert_redirected_to staff_root_path

    post staff_invitations_path, params: { email: "nope@example.com", role_key: "staff.super_administrator" }
    assert_redirected_to staff_root_path
  end

  test "operations manager cannot invite super admin" do
    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))

    assert_no_difference -> { Invitation.count } do
      post staff_invitations_path, params: { email: "bad@example.com", role_key: "staff.super_administrator" }
    end
    assert_redirected_to staff_invitations_path
    assert_match(/not allowed/i, flash[:alert])
  end

  test "suspended membership cannot invite" do
    suspended = memberships(:suspended_client_membership)
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    assert_raises(Invitations::Policy::Denied) do
      Invitations::Issue.call(
        inviter_membership: suspended,
        organization: organizations(:acme_client),
        email: "x@example.com",
        role_key: "client.client_member"
      )
    end
  end
end
