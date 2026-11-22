# frozen_string_literal: true

require "test_helper"

class AuthorizationRoleDefaultsTest < ActiveSupport::TestCase
  test "registry lists all 13 canonical roles" do
    assert_equal 13, Authorization::RoleDefaults.all_role_keys.size
    assert_includes Authorization::RoleDefaults.all_role_keys, "staff.super_administrator"
    assert_includes Authorization::RoleDefaults.all_role_keys, "client.client_finance"
  end

  test "super administrator defaults include all staff-applicable catalogue keys" do
    expected = Authorization::PermissionCatalogue.staff_applicable_keys
    actual = Authorization::RoleDefaults.keys_for("staff.super_administrator")

    assert_equal expected.sort, actual.sort
  end

  test "finance officer has billing view all without confidential documents default" do
    keys = Authorization::RoleDefaults.keys_for("staff.finance_officer")

    assert_includes keys, "billing.view_all"
    assert_not_includes keys, "documents.access_confidential"
  end

  test "operations manager does not default to confidential document access" do
    keys = Authorization::RoleDefaults.keys_for("staff.operations_manager")

    assert_not_includes keys, "documents.access_confidential"
    assert_includes keys, "team.invite"
  end

  test "client member cannot manage permissions by default" do
    keys = Authorization::RoleDefaults.keys_for("client.client_member")

    assert_not_includes keys, "team.manage_permissions"
    assert_not_includes keys, "team.invite"
  end
end
