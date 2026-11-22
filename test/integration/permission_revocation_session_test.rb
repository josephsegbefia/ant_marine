# frozen_string_literal: true

require "test_helper"

class PermissionRevocationSessionTest < ActionDispatch::IntegrationTest
  test "existing session loses invitation access after override removal" do
    actor = memberships(:super_admin_membership)
    target = memberships(:staff_membership)
    granter = Authorization::PermissionGranter.new(actor_membership: actor)

    granter.grant_allow!(target_membership: target, permission_key: "team.invite")
    sign_in_as(users(:staff_only), membership: target.reload)

    get staff_invitations_path
    assert_response :success

    granter.remove_override!(target_membership: target.reload, permission_key: "team.invite")

    get staff_invitations_path
    assert_redirected_to staff_root_path
    assert_match "permission", flash[:alert].to_s
  end
end
