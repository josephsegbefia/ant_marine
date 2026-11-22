# frozen_string_literal: true

require "test_helper"

class ClientPortalLayoutTest < ActionDispatch::IntegrationTest
  test "client home shows organisation identity and role" do
    membership = memberships(:client_owner_membership)
    sign_in_as(users(:client_owner), membership: membership)

    get client_root_path
    assert_response :success
    assert_select "h1", text: /Hello/
    assert_match membership.organization.name, response.body
    assert_match RoleLabels.label(membership.role_key), response.body
    assert_select "a.client-nav-button--active[href=?]", client_root_path
    assert_no_match(/Active projects/, response.body)
    assert_no_match(/Open requests/, response.body)
  end

  test "client owner with invite permission sees team nav" do
    sign_in_as(users(:client_owner), membership: memberships(:client_owner_membership))

    get client_root_path
    assert_select "a[href=?]", client_invitations_path, text: /invitation/i
  end

  test "client member without invite permission does not see team nav link" do
    sign_in_as(users(:client_only), membership: memberships(:client_membership))

    get client_root_path
    assert_response :success
    assert_select "a[href=?]", client_invitations_path, count: 0
  end

  test "staff user cannot access client portal" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    get client_root_path
    assert_redirected_to root_path
  end
end
