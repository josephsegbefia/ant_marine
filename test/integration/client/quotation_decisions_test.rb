# frozen_string_literal: true

require "test_helper"

class Client::QuotationDecisionsTest < ActionDispatch::IntegrationTest
  setup do
    @actor = memberships(:ops_manager_membership)
    @client_org = organizations(:acme_client)
    @quote = approve_quote!(create_ready_quote)
    @quote.update_columns(client_organization_id: @client_org.id)
    @release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @actor,
      quote: @quote,
      quote_revision: @quote.current_revision,
      client_organization: @client_org
    ).release
    sign_in_as(users(:client_owner), membership: memberships(:client_owner_membership))
  end

  test "authorized client can accept a simulated offer from the portal" do
    get client_quotation_path(@release)
    assert_response :success
    assert_includes response.body, "Accept quotation"
    assert_includes response.body, "Simulated offer"

    get decide_client_quotation_path(@release, type: "accepted")
    assert_response :success
    assert_includes response.body, "Simulated test decision"

    assert_difference -> { QuoteResponse.count }, 1 do
      post decide_client_quotation_path(@release), params: {
        decision: { response: "accepted", confirm: "1", idempotency_key: SecureRandom.uuid }
      }
    end
    assert_redirected_to client_quotation_path(@release)
    follow_redirect!
    assert_includes response.body, "Accepted (simulated test)"
    assert_not_includes response.body, "Accept quotation"
  end

  test "viewer without authority does not see decision actions" do
    sign_in_as(users(:client_only), membership: memberships(:client_membership))
    get client_quotation_path(@release)
    assert_response :success
    assert_not_includes response.body, "Accept quotation"
    assert_includes response.body, "authorised representative"
  end
end
