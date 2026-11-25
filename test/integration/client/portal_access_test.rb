# frozen_string_literal: true

require "test_helper"
require "test_helpers/enquiry_test_helper"

class Client::PortalAccessTest < ActionDispatch::IntegrationTest
  include EnquiryTestHelper

  setup do
    @acme = organizations(:acme_client)
    @other = organizations(:other_client)
    @member = memberships(:client_membership)
    sign_in_as(users(:client_only), membership: @member)
  end

  test "client home shows scoped empty states" do
    get client_root_path
    assert_response :success
    assert_includes response.body, "Welcome to your client portal"
    assert_includes response.body, @acme.name
  end

  test "client sees only linked requests for own organisation" do
    mine = submit_enquiry!(company_name: @acme.name, contact_email: "portal-a-#{SecureRandom.hex(3)}@example.com")
    mine.update_columns(client_organization_id: @acme.id)
    foreign = submit_enquiry!(company_name: @other.name, contact_email: "portal-b-#{SecureRandom.hex(3)}@example.com")
    foreign.update_columns(client_organization_id: @other.id)

    get client_requests_path
    assert_response :success
    assert_includes response.body, mine.reference_number
    assert_not_includes response.body, foreign.reference_number

    get client_request_path(foreign)
    assert_response :not_found
  end

  test "client quotation visibility requires portal release" do
    get client_quotations_path
    assert_response :success
    assert_includes response.body, "No quotations released yet"
  end

  test "revoked membership loses portal access" do
    Clients::MembershipLifecycle.revoke!(
      actor_membership: memberships(:ops_manager_membership),
      membership: @member
    )
    get client_requests_path
    assert_response :redirect
    assert_includes [ new_session_path, workspace_selection_path ], URI.parse(response.redirect_url).path
  end
end
