# frozen_string_literal: true

require "test_helper"

class ClientInvitationsTest < ActionDispatch::IntegrationTest
  test "client owner can invite colleague" do
    sign_in_as(users(:client_owner), membership: memberships(:client_owner_membership))

    assert_difference -> { Invitation.count }, 1 do
      post client_invitations_path, params: { email: "colleague@example.com", role_key: "client.client_member" }
    end
    assert_redirected_to client_invitations_path
  end

  test "client member cannot manage invitations" do
    sign_in_as(users(:client_only), membership: memberships(:client_membership))

    get client_invitations_path
    assert_redirected_to client_root_path
  end

  test "client cannot invite staff role" do
    sign_in_as(users(:client_owner), membership: memberships(:client_owner_membership))

    assert_no_difference -> { Invitation.count } do
      post client_invitations_path, params: { email: "hack@example.com", role_key: "staff.general_staff" }
    end
    assert_redirected_to client_invitations_path
  end
end
