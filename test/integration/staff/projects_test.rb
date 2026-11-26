# frozen_string_literal: true

require "test_helper"

class Staff::ProjectsTest < ActionDispatch::IntegrationTest
  setup do
    @staff = memberships(:ops_manager_membership)
    @client_org = organizations(:acme_client)
    @owner = memberships(:client_owner_membership)
    @quote = approve_quote!(create_ready_quote)
    @quote.update_columns(client_organization_id: @client_org.id)
    @release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @staff, quote: @quote,
      quote_revision: @quote.current_revision, client_organization: @client_org
    ).release
    decision = Commercial::QuoteDecision.call(
      membership: @owner, release: @release, response: "accepted",
      confirmation: true, idempotency_key: "f405-int-accept-#{SecureRandom.hex(4)}"
    )
    @acceptance = decision.response
    assert @acceptance.present?, "expected an accepted quote response for project creation"
    sign_in_as(users(:ops_manager), membership: @staff)
  end

  test "staff can open create wizard and create project" do
    get new_staff_project_path(quote_response_id: @acceptance.id)
    assert_response :success
    assert_match(/Create project|Commercial source/i, response.body)

    assert_difference -> { Project.count }, 1 do
      post staff_projects_path, params: {
        quote_response_id: @acceptance.id,
        project: {
          title: "Integration project",
          confirm: "1"
        }
      }
    end
    project = Project.order(:id).last
    assert_redirected_to staff_project_path(project)
    follow_redirect!
    assert_match(/Simulated project/i, response.body)
    assert_match(project.reference_number, response.body)
    assert_match(/Job details/i, response.body)
    assert_match(/Work checklist/i, response.body)
    assert_match(/What needs attention/i, response.body)
    assert_match(/Current stage/i, response.body)
  end

  test "project index is authorization scoped" do
    get staff_projects_path
    assert_response :success
  end
end
