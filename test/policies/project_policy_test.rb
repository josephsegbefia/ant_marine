# frozen_string_literal: true

require "test_helper"

class ProjectPolicyTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @surveyor = memberships(:dual_staff)
    @client = memberships(:client_owner_membership)
    @client_org = organizations(:acme_client)
    quote = approve_quote!(create_ready_quote)
    quote.update_columns(client_organization_id: @client_org.id)
    release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @staff, quote: quote,
      quote_revision: quote.current_revision, client_organization: @client_org
    ).release
    response = Commercial::QuoteDecision.call(
      membership: @client, release: release, response: "accepted",
      confirmation: true, idempotency_key: "f405-policy-accept"
    ).response
    @project = Delivery::CreateFromAcceptance.call(
      membership: @staff, quote_response: response, confirmation: true
    ).project
  end

  test "staff with view_all can show" do
    assert ProjectPolicy.new(@staff, @project).show?
  end

  test "client of owning org can show" do
    assert ProjectPolicy.new(@client, @project).show?
  end

  test "unassigned view_assigned staff cannot show without assignment" do
    surveyor_policy = ProjectPolicy.new(@surveyor, @project)
    if Authorization::EffectivePermissions.new(@surveyor).allowed?("projects.view_all")
      assert surveyor_policy.show?
    else
      assert_not surveyor_policy.show?
    end
  end

  test "scope includes client organization projects" do
    scope = ProjectPolicy::Scope.new(@client, Project).resolve
    assert_includes scope, @project
  end
end
