# frozen_string_literal: true

require "test_helper"

class AuthorizationEffectivePermissionsTest < ActiveSupport::TestCase
  test "role defaults grant and withhold expected staff permissions" do
    super_admin = memberships(:super_admin_membership)
    general = memberships(:staff_membership)
    ops_manager = memberships(:ops_manager_membership)

    assert Authorization::EffectivePermissions.allowed?(membership: super_admin, permission_key: "team.invite")
    assert_not Authorization::EffectivePermissions.allowed?(membership: general, permission_key: "team.invite")
    assert Authorization::EffectivePermissions.allowed?(membership: ops_manager, permission_key: "team.invite")
    assert_not Authorization::EffectivePermissions.allowed?(membership: ops_manager, permission_key: "documents.access_confidential")
  end

  test "seeded finance officer defaults match matrix for billing and confidential" do
    keys = RolePermission.where(role_key: "staff.finance_officer").joins(:permission).pluck("permissions.key")

    assert_includes keys, "billing.view_all"
    assert_not_includes keys, "documents.access_confidential"
  end

  test "client memberships only resolve client-domain keys" do
    client = memberships(:client_owner_membership)

    assert Authorization::EffectivePermissions.allowed?(membership: client, permission_key: "team.invite")
    assert_not Authorization::EffectivePermissions.allowed?(membership: client, permission_key: "inquiries.view_all")
  end

  test "deny override beats role default allow" do
    membership = memberships(:ops_manager_membership)
    permission = Permission.find_by!(key: "team.invite")

    PermissionOverride.create!(
      membership: membership,
      permission: permission,
      effect: "deny",
      granted_by_membership: memberships(:super_admin_membership)
    )

    assert_not Authorization::EffectivePermissions.allowed?(membership: membership.reload, permission_key: "team.invite")
  end

  test "suspended membership denies all checks" do
    suspended = memberships(:suspended_client_membership)

    assert_not Authorization::EffectivePermissions.allowed?(membership: suspended, permission_key: "team.view")
  end

  test "allow override grants permission beyond role default" do
    membership = memberships(:staff_membership)
    permission = Permission.find_by!(key: "team.invite")

    PermissionOverride.create!(
      membership: membership,
      permission: permission,
      effect: "allow",
      granted_by_membership: memberships(:super_admin_membership)
    )

    assert Authorization::EffectivePermissions.allowed?(membership: membership.reload, permission_key: "team.invite")
  end
end
