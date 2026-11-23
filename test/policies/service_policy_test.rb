# frozen_string_literal: true

require "test_helper"

class ServicePolicyTest < ActiveSupport::TestCase
  setup do
    @org = organizations(:ant_marine)
    @service = services(:marine_surveys_draft)
    @new_service = Service.new(organization: @org, title: "Draft", slug: "draft-test")
  end

  test "content manager staff may new and create" do
    policy = ServicePolicy.new(memberships(:super_admin_membership), @new_service)

    assert policy.new?
    assert policy.create?
  end

  test "general staff cannot new or create" do
    policy = ServicePolicy.new(memberships(:staff_membership), @new_service)

    assert_not policy.new?
    assert_not policy.create?
  end

  test "client membership cannot new or create" do
    policy = ServicePolicy.new(memberships(:client_membership), @new_service)

    assert_not policy.new?
    assert_not policy.create?
  end

  test "edit and update require content manage and same org" do
    manager = ServicePolicy.new(memberships(:super_admin_membership), @service)

    assert manager.edit?
    assert manager.update?
  end
end
