# frozen_string_literal: true

require "test_helper"

class AuthorizationPermissionGranterSecurityTest < ActiveSupport::TestCase
  test "cross-organisation override changes are denied" do
    actor = memberships(:super_admin_membership)
    target = memberships(:client_owner_membership)
    granter = Authorization::PermissionGranter.new(actor_membership: actor)

    assert_raises(Authorization::PermissionGranter::Denied) do
      granter.grant_allow!(target_membership: target, permission_key: "team.invite")
    end
  end

  test "granter cannot target a membership in another organisation" do
    actor = memberships(:client_owner_membership)
    target = memberships(:staff_membership)
    granter = Authorization::PermissionGranter.new(actor_membership: actor)

    assert_raises(Authorization::PermissionGranter::Denied) do
      granter.grant_allow!(target_membership: target, permission_key: "team.invite")
    end
  end

  test "suspended actor cannot grant overrides" do
    actor = memberships(:suspended_client_membership)
    granter = Authorization::PermissionGranter.new(actor_membership: actor)

    assert_raises(Authorization::PermissionGranter::Denied) do
      granter.grant_deny!(
        target_membership: memberships(:client_admin_membership),
        permission_key: "team.invite"
      )
    end
  end
end
