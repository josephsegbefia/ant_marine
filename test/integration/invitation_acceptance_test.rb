# frozen_string_literal: true

require "test_helper"

class InvitationAcceptanceTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "GET show does not consume invitation" do
    get invitation_path(FIXTURE_STAFF_TOKEN)
    assert_response :success
    assert_equal "pending", invitations(:pending_staff_invite).reload.status
  end

  test "new user accepts invitation and receives membership" do
    result = issue_invitation!(
      inviter_membership: memberships(:super_admin_membership),
      organization: organizations(:ant_marine),
      email: "brandnew@example.com",
      role_key: "staff.general_staff"
    )

    get invitation_path(result.raw_token)
    assert_response :success

    post invitation_setup_path(result.raw_token), params: {
      full_name: "Brand New",
      password: "new-password-12",
      password_confirmation: "new-password-12"
    }

    assert_redirected_to staff_root_path
    user = User.find_by!(email: "brandnew@example.com")
    assert user.email_verified_at.present?
    assert Membership.exists?(user: user, organization: organizations(:ant_marine), status: "active")
    assert_equal "accepted", result.invitation.reload.status
  end

  test "existing user must sign in with invited email" do
    result = issue_invitation!(
      inviter_membership: memberships(:super_admin_membership),
      organization: organizations(:ant_marine),
      email: users(:staff_only).email,
      role_key: "staff.finance_officer"
    )

    get invitation_setup_path(result.raw_token)
    assert_redirected_to new_session_path
  end

  test "wrong signed-in user cannot accept" do
    result = issue_invitation!(
      inviter_membership: memberships(:super_admin_membership),
      organization: organizations(:acme_client),
      email: "joiner@example.com",
      role_key: "client.client_member"
    )

    sign_in_as(users(:client_only), membership: memberships(:client_membership))
    post invitation_setup_path(result.raw_token), params: {
      full_name: "Nope",
      password: "new-password-12",
      password_confirmation: "new-password-12"
    }
    assert_response :unprocessable_entity
  end

  test "expired invitation is rejected" do
    get invitation_path(FIXTURE_EXPIRED_TOKEN)
    assert_response :success
    assert_select "h2", text: /expired/i
  end

  test "forged token is rejected" do
    get invitation_path("not-a-real-token")
    assert_response :success
    assert_select "h2", text: /not valid/i
  end

  test "mailer enqueues on issue" do
    assert_enqueued_emails 1 do
      issue_invitation!(
        inviter_membership: memberships(:super_admin_membership),
        organization: organizations(:ant_marine),
        email: "mailtest@example.com",
        role_key: "staff.general_staff"
      )
    end
  end
end
