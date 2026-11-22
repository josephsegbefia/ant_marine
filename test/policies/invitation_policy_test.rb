# frozen_string_literal: true

require "test_helper"

class InvitationPolicyTest < ActiveSupport::TestCase
  test "super admin holds team.invite at policy layer" do
    policy = InvitationPolicy.new(memberships(:super_admin_membership), nil)

    assert policy.allowed?("team.invite")
  end

  test "general staff lacks team.invite at policy layer" do
    policy = InvitationPolicy.new(memberships(:staff_membership), nil)

    assert_not policy.allowed?("team.invite")
  end
end
