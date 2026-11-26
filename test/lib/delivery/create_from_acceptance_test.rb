# frozen_string_literal: true

require "test_helper"

class Delivery::CreateFromAcceptanceTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client_org = organizations(:acme_client)
    @owner = memberships(:client_owner_membership)
    @quote = approve_quote!(create_ready_quote)
    @quote.update_columns(client_organization_id: @client_org.id)
    @release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @staff,
      quote: @quote,
      quote_revision: @quote.current_revision,
      client_organization: @client_org
    ).release
    @response = Commercial::QuoteDecision.call(
      membership: @owner,
      release: @release,
      response: "accepted",
      confirmation: true,
      idempotency_key: "f405-accept-1"
    ).response
  end

  test "staff creates simulated project from exact acceptance" do
    result = Delivery::CreateFromAcceptance.call(
      membership: @staff,
      quote_response: @response,
      attributes: { title: "Harbour survey delivery" },
      confirmation: true
    )
    assert result.created
    project = result.project
    assert project.simulated?
    assert_equal @response.id, project.quote_response_id
    assert_equal @quote.current_revision_id, project.quote_revision_id
    assert_equal @client_org.id, project.client_organization_id
    assert_match(/\AANT-PRJ-\d{4}-\d{5}\z/, project.reference_number)
    assert_equal "planning", project.internal_status
    assert project.project_milestones.exists?(kind: "project_initiated", status: "completed")
    assert_equal @response.offer_snapshot["currency"] || @quote.current_revision.currency,
                 project.commercial_snapshot["currency"]
  end

  test "duplicate conversion returns existing project" do
    first = Delivery::CreateFromAcceptance.call(
      membership: @staff, quote_response: @response, confirmation: true
    )
    second = Delivery::CreateFromAcceptance.call(
      membership: @staff, quote_response: @response, confirmation: true,
      attributes: { title: "Other title" }
    )
    assert first.created
    assert_not second.created
    assert_equal first.project.id, second.project.id
    assert_equal 1, Project.where(quote_response_id: @response.id).count
  end

  test "declined offer cannot create a project" do
    decline_quote = approve_quote!(create_ready_quote)
    decline_quote.update_columns(client_organization_id: @client_org.id)
    release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @staff, quote: decline_quote,
      quote_revision: decline_quote.current_revision, client_organization: @client_org
    ).release
    declined = Commercial::QuoteDecision.call(
      membership: @owner, release: release, response: "declined",
      reason: "Budget", confirmation: true, idempotency_key: "f405-decline"
    ).response

    assert_raises(Delivery::CreateFromAcceptance::InvalidState) do
      Delivery::CreateFromAcceptance.call(membership: @staff, quote_response: declined, confirmation: true)
    end
  end

  test "client membership cannot create projects" do
    assert_raises(Delivery::CreateFromAcceptance::Denied) do
      Delivery::CreateFromAcceptance.call(membership: @owner, quote_response: @response, confirmation: true)
    end
  end

  test "creation does not mutate accepted commercial content" do
    revision = @quote.current_revision
    title = revision.title
    total = revision.total_cents
    Delivery::CreateFromAcceptance.call(membership: @staff, quote_response: @response, confirmation: true)
    revision.reload
    assert_equal title, revision.title
    assert_equal total, revision.total_cents
    assert_equal "accepted", @response.reload.response
  end
end
