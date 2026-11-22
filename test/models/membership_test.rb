require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "rejects staff role on client organisation" do
    membership = Membership.new(
      user: users(:client_only),
      organization: organizations(:acme_client),
      role_key: "staff.general_staff",
      status: "active"
    )
    assert_not membership.valid?
  end

  test "rejects client role on ant marine organisation" do
    membership = Membership.new(
      user: users(:staff_only),
      organization: organizations(:ant_marine),
      role_key: "client.client_member",
      status: "active"
    )
    assert_not membership.valid?
  end

  test "duplicate membership rejected" do
    duplicate = Membership.new(
      user: users(:staff_only),
      organization: organizations(:ant_marine),
      role_key: "staff.general_staff",
      status: "active"
    )
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
