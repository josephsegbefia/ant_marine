# frozen_string_literal: true

require "test_helper"

class InvitationsPolicyTest < ActiveSupport::TestCase
  test "super admin can invite staff roles except super admin" do
    policy = Invitations::Policy.new(inviter_membership: memberships(:super_admin_membership))
    org = organizations(:ant_marine)

    assert policy.issue_allowed?(organization: org, role_key: "staff.general_staff")
    assert_not policy.issue_allowed?(organization: org, role_key: "staff.super_administrator")
  end

  test "operations manager cannot invite super admin or ops manager" do
    policy = Invitations::Policy.new(inviter_membership: memberships(:ops_manager_membership))
    org = organizations(:ant_marine)

    assert policy.issue_allowed?(organization: org, role_key: "staff.general_staff")
    assert_not policy.issue_allowed?(organization: org, role_key: "staff.operations_manager")
  end

  test "general staff cannot invite" do
    policy = Invitations::Policy.new(inviter_membership: memberships(:staff_membership))
    org = organizations(:ant_marine)

    assert_not policy.issue_allowed?(organization: org, role_key: "staff.general_staff")
  end

  test "client owner can invite client roles in own org" do
    policy = Invitations::Policy.new(inviter_membership: memberships(:client_owner_membership))
    org = organizations(:acme_client)

    assert policy.issue_allowed?(organization: org, role_key: "client.client_member")
    assert_not policy.issue_allowed?(organization: org, role_key: "client.org_owner")
    assert_not policy.issue_allowed?(organization: org, role_key: "staff.general_staff")
  end

  test "client cannot invite into another client organisation" do
    policy = Invitations::Policy.new(inviter_membership: memberships(:client_owner_membership))

    assert_not policy.issue_allowed?(organization: organizations(:other_client), role_key: "client.client_member")
  end

  test "staff can invite client roles into client organisation" do
    policy = Invitations::Policy.new(inviter_membership: memberships(:super_admin_membership))

    assert policy.issue_allowed?(organization: organizations(:acme_client), role_key: "client.client_member")
  end
end
