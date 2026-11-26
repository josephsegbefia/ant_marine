# frozen_string_literal: true

require "test_helper"

class Staff::ClientsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))
  end

  test "lists client organisations" do
    get staff_clients_path
    assert_response :success
    assert_includes response.body, organizations(:acme_client).name
    assert_includes response.body, "Client directory"
    assert_includes response.body, "Awaiting portal"
  end

  test "filters clients awaiting portal access" do
    get staff_clients_path(view: "awaiting")
    assert_response :success
    assert_includes response.body, "Awaiting portal"
  end

  test "creates a client organisation" do
    assert_difference -> { Organization.client.count }, 1 do
      post staff_clients_path, params: {
        organization: { name: "Tema Marine Services", primary_contact_email: "hello@tema.test" }
      }
    end
    org = Organization.client.order(:created_at).last
    assert_redirected_to staff_client_path(org)
    follow_redirect!
    assert_includes response.body, "Tema Marine Services"
  end

  test "shows client detail tabs" do
    get staff_client_path(organizations(:acme_client))
    assert_response :success
    assert_includes response.body, "Contacts &amp; access"
    assert_includes response.body, "Service requests"
  end

  test "denies general staff without qualify permission" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))
    get staff_clients_path
    assert_response :redirect
  end
end
