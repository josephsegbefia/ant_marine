# frozen_string_literal: true

require "test_helper"

class Client::CommercialDecisionRulesTest < ActionDispatch::IntegrationTest
  setup do
    @actor = memberships(:ops_manager_membership)
    @client_org = organizations(:acme_client)
    @owner = memberships(:client_owner_membership)
    @quote = approve_quote!(create_ready_quote)
    @quote.update_columns(client_organization_id: @client_org.id)
    @release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @actor,
      quote: @quote,
      quote_revision: @quote.current_revision,
      client_organization: @client_org
    ).release
    sign_in_as(users(:client_owner), membership: @owner)
  end

  test "decline closes the offer to a later accept" do
    post decide_client_quotation_path(@release), params: {
      decision: { response: "declined", reason: "Budget postponed", confirm: "1", idempotency_key: "rule-decline" }
    }
    assert_redirected_to client_quotation_path(@release)

    post decide_client_quotation_path(@release), params: {
      decision: { response: "accepted", confirm: "1", idempotency_key: "rule-accept-after-decline" }
    }
    assert_response :unprocessable_entity
    assert_match(/final decision|already/i, flash.now[:alert].to_s + response.body)
    assert_equal 1, QuoteResponse.where(quote_portal_release_id: @release.id).count
  end

  test "request changes keeps history and allows a later terminal decision" do
    post decide_client_quotation_path(@release), params: {
      decision: { response: "changes_requested", reason: "Add mobilisation", confirm: "1", idempotency_key: "rule-changes" }
    }
    assert_redirected_to client_quotation_path(@release)

    post decide_client_quotation_path(@release), params: {
      decision: { response: "accepted", confirm: "1", idempotency_key: "rule-accept-after-changes" }
    }
    assert_redirected_to client_quotation_path(@release)
    assert_equal %w[changes_requested accepted], QuoteResponse.where(quote_portal_release_id: @release.id).order(:id).pluck(:response)
  end
end
