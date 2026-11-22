# frozen_string_literal: true

require "test_helper"

class PermissionEpochSessionTest < ActionDispatch::IntegrationTest
  test "stale session permission epoch refreshes on authenticated request" do
    actor = memberships(:super_admin_membership)
    target = memberships(:staff_membership)
    sign_in_as(users(:staff_only), membership: target)

    session_id = Current.session.id
    assert_equal 0, Session.find(session_id).permission_epoch_at_issue

    Authorization::PermissionGranter.new(actor_membership: actor).grant_allow!(
      target_membership: target,
      permission_key: "team.invite"
    )
    target.reload
    assert_equal 1, target.permission_epoch

    get staff_root_path
    assert_response :success
    assert_equal target.permission_epoch, Session.find(session_id).permission_epoch_at_issue
  end
end
