# frozen_string_literal: true

require "test_helper"

class Invitations::PolicyClientRolesTest < ActiveSupport::TestCase
  test "operations manager can list client invite roles for a client organisation" do
    policy = Invitations::Policy.new(inviter_membership: memberships(:ops_manager_membership))
    roles = policy.allowed_roles_for(organization: organizations(:acme_client))

    assert_includes roles, "client.client_member"
    assert_includes roles, "client.org_administrator"
    assert_not_includes roles, "client.org_owner"
    assert_not_includes roles, "staff.operations_manager"
  end
end
