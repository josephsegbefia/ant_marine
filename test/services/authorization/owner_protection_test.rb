# frozen_string_literal: true

require "test_helper"

class AuthorizationOwnerProtectionTest < ActiveSupport::TestCase
  test "detects last active super administrator" do
    org = organizations(:ant_marine)
    sole = memberships(:super_admin_membership)

    assert Authorization::OwnerProtection.last_active_super_admin?(organization: org, excluding: sole)
    assert_not Authorization::OwnerProtection.last_active_super_admin?(organization: org)
  end

  test "detects last active client org owner" do
    org = organizations(:acme_client)
    owner = memberships(:client_owner_membership)

    assert Authorization::OwnerProtection.last_active_org_owner?(organization: org, excluding: owner)
    assert_not Authorization::OwnerProtection.last_active_org_owner?(organization: org)
  end

  test "ensure_not_last_protected raises for sole protected roles" do
    assert_raises(Authorization::OwnerProtection::ProtectedRoleViolation) do
      Authorization::OwnerProtection.ensure_not_last_protected!(membership: memberships(:super_admin_membership))
    end

    assert_raises(Authorization::OwnerProtection::ProtectedRoleViolation) do
      Authorization::OwnerProtection.ensure_not_last_protected!(membership: memberships(:client_owner_membership))
    end
  end
end
