# frozen_string_literal: true

require "test_helper"

class AuthorizationPermissionCatalogueTest < ActiveSupport::TestCase
  test "catalogue defines 72 stable permission keys" do
    keys = Authorization::PermissionCatalogue.all_keys
    assert_equal 72, keys.size
    assert_equal 72, keys.uniq.size
  end

  test "fetch raises on unknown key" do
    assert_raises(Authorization::PermissionCatalogue::UnknownKey) do
      Authorization::PermissionCatalogue.fetch("not.a.real.permission")
    end
  end

  test "staff and client applicable key sets are disjoint from wrong domain" do
    staff = Authorization::PermissionCatalogue.staff_applicable_keys
    client = Authorization::PermissionCatalogue.client_applicable_keys

    assert_includes staff, "team.invite"
    assert_includes client, "inquiries.create"
    assert_not_includes staff, "inquiries.create"
    assert_not_includes client, "inquiries.view_all"
  end

  test "applicable keys follow membership organisation kind" do
    staff_membership = memberships(:staff_membership)
    client_membership = memberships(:client_membership)

    staff_keys = Authorization::PermissionCatalogue.applicable_keys_for_membership(staff_membership)
    client_keys = Authorization::PermissionCatalogue.applicable_keys_for_membership(client_membership)

    assert_includes staff_keys, "projects.view_all"
    assert_includes client_keys, "projects.view_org"
    assert_not_includes client_keys, "projects.view_all"
  end
end
