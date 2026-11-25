# frozen_string_literal: true

require "test_helper"

class Client::QuotationsPortalTest < ActionDispatch::IntegrationTest
  setup do
    @actor = memberships(:ops_manager_membership)
    @client_org = organizations(:acme_client)
    @member = memberships(:client_membership)
    @quote = approve_quote!(create_ready_quote)
    @quote.update_columns(client_organization_id: @client_org.id)
    @release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @actor,
      quote: @quote,
      quote_revision: @quote.current_revision,
      client_organization: @client_org
    ).release
    sign_in_as(users(:client_only), membership: @member)
  end

  test "client can view and download a simulated released quotation" do
    get client_quotations_path
    assert_response :success
    assert_includes response.body, @quote.reference_number
    assert_includes response.body, "Simulated"

    get client_quotation_path(@release)
    assert_response :success
    assert_includes response.body, @quote.current_revision.title
    assert_includes response.body, "Simulated offer"
    assert_not_includes response.body, "Accept quotation"
    assert_not_includes response.body, "Decline quotation"

    get pdf_client_quotation_path(@release)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/no-store/, response.headers["Cache-Control"].to_s)
    assert_match(/SIMULATED/, response.headers["Content-Disposition"].to_s)
  end

  test "draft and unreleased versions stay hidden" do
    draft = create_ready_quote
    draft.update_columns(client_organization_id: @client_org.id)

    get client_quotations_path
    assert_not_includes response.body, draft.reference_number
  end

  test "internal notes never appear on client quotation pages" do
    get client_quotation_path(@release)
    assert_not_includes response.body, "internal note"
    assert_not_includes response.body, "staff note"
  end
end
