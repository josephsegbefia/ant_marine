# frozen_string_literal: true

require "test_helper"

class InvitationsUiTest < ActionDispatch::IntegrationTest
  test "staff invitations index shows human labels and no provisional copy" do
    Invitation.where(organization: organizations(:ant_marine)).delete_all

    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    get staff_invitations_path
    assert_response :success
    assert_match(/No invitations yet/, response.body)
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
    assert_no_match(/invitation-row__meta[^<]*staff\./, response.body)
  end

  test "client invitations index scoped to organisation" do
    sign_in_as(users(:client_owner), membership: memberships(:client_owner_membership))

    get client_invitations_path
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
    assert_match(/No invitations yet/, response.body)
  end
end
