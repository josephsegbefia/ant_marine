# frozen_string_literal: true

require "test_helper"

class AuthorizationPermissionGranterTest < ActiveSupport::TestCase
  setup do
    @actor = memberships(:super_admin_membership)
    @target = memberships(:staff_membership)
    @granter = Authorization::PermissionGranter.new(actor_membership: @actor)
  end

  test "super admin can grant allow override for permission they hold" do
    assert_difference -> { @target.permission_overrides.count }, 1 do
      @granter.grant_allow!(target_membership: @target, permission_key: "team.invite", reason: "Cover shift")
    end

    assert Authorization::EffectivePermissions.allowed?(membership: @target.reload, permission_key: "team.invite")
    assert_equal 1, @target.permission_epoch
  end

  test "general staff cannot change overrides" do
    granter = Authorization::PermissionGranter.new(actor_membership: @target)

    assert_raises(Authorization::PermissionGranter::Denied) do
      granter.grant_allow!(target_membership: memberships(:ops_manager_membership), permission_key: "team.invite")
    end
  end

  test "actor cannot grant permission they lack" do
    actor = memberships(:ops_manager_membership)
    granter = Authorization::PermissionGranter.new(actor_membership: actor)

    assert_raises(Authorization::PermissionGranter::Denied) do
      granter.grant_allow!(target_membership: @target, permission_key: "team.manage_staff_permissions")
    end
  end

  test "protected permissions reject override changes" do
    assert_raises(Authorization::PermissionGranter::Denied) do
      @granter.grant_allow!(target_membership: @target, permission_key: "team.manage_roles")
    end
  end

  test "deny_only permission rejects allow override" do
    assert_raises(Authorization::PermissionGranter::Denied) do
      @granter.grant_allow!(
        target_membership: memberships(:ops_manager_membership),
        permission_key: "documents.access_confidential"
      )
    end
  end

  test "remove_override clears row and bumps epoch" do
    @granter.grant_allow!(target_membership: @target, permission_key: "team.invite")
    epoch = @target.reload.permission_epoch

    @granter.remove_override!(target_membership: @target, permission_key: "team.invite")

    @target.reload
    assert_empty @target.permission_overrides.where(permission: Permission.find_by!(key: "team.invite"))
    assert @target.permission_epoch > epoch
    assert_not Authorization::EffectivePermissions.allowed?(membership: @target, permission_key: "team.invite")
  end
end
