# frozen_string_literal: true

require "test_helper"

class Client::ProjectsTest < ActionDispatch::IntegrationTest
  setup do
    @staff = memberships(:ops_manager_membership)
    @client_org = organizations(:acme_client)
    @owner = memberships(:client_owner_membership)
    quote = approve_quote!(create_ready_quote)
    quote.update_columns(client_organization_id: @client_org.id)
    release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @staff, quote: quote,
      quote_revision: quote.current_revision, client_organization: @client_org
    ).release
    response = Commercial::QuoteDecision.call(
      membership: @owner, release: release, response: "accepted",
      confirmation: true, idempotency_key: "f405-client-accept"
    ).response
    @project = Delivery::CreateFromAcceptance.call(
      membership: @staff, quote_response: response, confirmation: true,
      attributes: { title: "Client visible project", internal_notes: "SECRET STAFF NOTE" }
    ).project
  end

  test "client can view own project without internal notes" do
    sign_in_as(users(:client_owner), membership: @owner)
    get client_projects_path
    assert_response :success
    assert_match(@project.reference_number, response.body)

    get client_project_path(@project)
    assert_response :success
    assert_match(/Simulated project/i, response.body)
    assert_no_match(/SECRET STAFF NOTE/, response.body)
  end

  test "client cannot create projects" do
    sign_in_as(users(:client_owner), membership: @owner)
    get new_staff_project_path(quote_response_id: @project.quote_response_id)
    assert_response :redirect
  end
end
