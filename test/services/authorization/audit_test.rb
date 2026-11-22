# frozen_string_literal: true

require "test_helper"

class AuthorizationAuditTest < ActiveSupport::TestCase
  test "override grant writes audit event with safe metadata" do
    actor = memberships(:super_admin_membership)
    target = memberships(:staff_membership)
    permission = Permission.find_by!(key: "team.invite")

    assert_difference -> { AuditEvent.where(event_type: "permission.override_granted").count }, 1 do
      Authorization::Audit.override_granted(
        actor_membership: actor,
        target_membership: target,
        permission: permission,
        effect: "allow",
        previous_effect: nil,
        reason: "Testing"
      )
    end

    event = AuditEvent.where(event_type: "permission.override_granted").order(:id).last
    assert_equal target.organization_id, event.organization_id
    assert_equal "team.invite", event.metadata["permission_key"]
    assert_equal "allow", event.metadata["effect"]
    assert_nil event.metadata["token"]
  end
end
