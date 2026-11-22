# frozen_string_literal: true

require "test_helper"

class AuthorizationEffectivePermissionsSecurityTest < ActiveSupport::TestCase
  test "unknown permission keys fail closed" do
    membership = memberships(:super_admin_membership)

    assert_not Authorization::EffectivePermissions.allowed?(
      membership: membership,
      permission_key: "team.nonexistent_capability"
    )
  end

  test "client membership cannot resolve staff-only catalogue keys" do
    membership = memberships(:client_owner_membership)

    assert_not Authorization::EffectivePermissions.allowed?(
      membership: membership,
      permission_key: "inquiries.view_all"
    )
  end

  test "override rows belong only to the target membership" do
    target = memberships(:staff_membership)
    other = memberships(:ops_manager_membership)
    permission = Permission.find_by!(key: "team.manage_staff_permissions")

    PermissionOverride.create!(
      membership: target,
      permission: permission,
      effect: "allow",
      granted_by_membership: memberships(:super_admin_membership)
    )

    assert Authorization::EffectivePermissions.allowed?(
      membership: target.reload,
      permission_key: "team.manage_staff_permissions"
    )
    assert_not Authorization::EffectivePermissions.allowed?(
      membership: other,
      permission_key: "team.manage_staff_permissions"
    )
  end
end
