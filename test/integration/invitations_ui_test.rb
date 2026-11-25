# frozen_string_literal: true

require "test_helper"

class InvitationsUiTest < ActionDispatch::IntegrationTest
  test "staff invitations index shows human labels and no provisional copy" do
    Invitation.where(organization: organizations(:ant_marine)).delete_all

    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    get staff_invitations_path
    assert_response :success
    assert_match(/No active invitations/, response.body)
    refute_match(/provisional/i, response.body)
    assert_no_match(/invitation-row__meta[^<]*staff\./, response.body)
    assert_match(/General Staff/, response.body)
    assert_match(/Send invitation/, response.body)
  end

  test "staff invitations list is database backed with readable status" do
    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    get staff_invitations_path
    assert_response :success
    assert_match(/newstaff@example.com/, response.body)
    assert_match(/General Staff/, response.body)
    assert_match(/Pending/, response.body)
    assert_select ".invitation-row__actions", text: /Cancel/
    assert_select ".invitation-row__actions", text: /Resend/
    assert_no_match(/invitation-row__meta[^<]*staff\./, response.body)
  end

  test "staff invitations default to active and can show all history" do
    accepted = Invitation.create!(
      organization: organizations(:ant_marine),
      email: "accepted.history@example.com",
      role_key: "staff.general_staff",
      token_digest: Invitations::Token.digest("accepted-history-token"),
      status: "accepted",
      expires_at: 3.days.from_now,
      invited_by_membership: memberships(:super_admin_membership),
      accepted_by_user: users(:staff_only),
      accepted_at: 1.day.ago
    )

    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    get staff_invitations_path
    assert_response :success
    assert_match(/newstaff@example.com/, response.body)
    assert_no_match(/accepted\.history@example\.com/, response.body)
    assert_select ".ant-section-tabs__tab--active", text: /Active/

    get staff_invitations_path(show: "all")
    assert_response :success
    assert_match(/accepted\.history@example\.com/, response.body)
    assert_match(/Accepted/, response.body)
  ensure
    accepted&.destroy
  end

  test "staff invitations paginate inside the recent list" do
    Invitation.where(organization: organizations(:ant_marine)).delete_all
    8.times do |i|
      Invitation.create!(
        organization: organizations(:ant_marine),
        email: "page-invite-#{i}@example.com",
        role_key: "staff.general_staff",
        token_digest: Invitations::Token.digest("page-invite-token-#{i}"),
        status: "pending",
        expires_at: 7.days.from_now,
        invited_by_membership: memberships(:super_admin_membership)
      )
    end

    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))
    get staff_invitations_path
    assert_response :success
    assert_select ".invitation-row", count: 6
    assert_select ".ant-pagination__summary", text: /Showing 1–6 of 8 invitations/
    assert_select ".ant-pagination__page", text: "Page 1 of 2"

    get staff_invitations_path(page: 2)
    assert_select ".invitation-row", count: 2
    assert_select ".ant-pagination__summary", text: /Showing 7–8 of 8 invitations/
  end

  test "client invitations index scoped to organisation" do
    sign_in_as(users(:client_owner), membership: memberships(:client_owner_membership))

    get client_invitations_path(show: "all")
    assert_response :success
    refute_match(/provisional/i, response.body)
    assert_match(/Client Member/, response.body)
    assert_no_match(/invitation-row__meta[^<]*client\./, response.body)
    assert_match(/expired@example.com/, response.body)
    assert_match(/Expired/, response.body)
    refute_match(/newstaff@example.com/, response.body)
  end

  test "client admin empty invitations for org without invites" do
    Invitation.where(organization: organizations(:acme_client)).delete_all

    sign_in_as(users(:client_owner), membership: memberships(:client_owner_membership))

    get client_invitations_path
    assert_response :success
    assert_match(/No active invitations/, response.body)
  end
end
