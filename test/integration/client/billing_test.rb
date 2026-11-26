# frozen_string_literal: true

require "test_helper"

class Client::BillingTest < ActionDispatch::IntegrationTest
  setup do
    @staff = memberships(:ops_manager_membership)
    @client_owner = memberships(:client_owner_membership)
    @finance = create_finance_membership!
    @project = create_simulated_project!
    draft = Billing::CreateDraft.call(
      membership: @finance,
      project: @project,
      attributes: {
        description: "Client portal invoice",
        issue_on: Date.current,
        due_on: Date.current + 7
      },
      lines: [ { description: "Item", quantity: "1", unit: "Lot", unit_amount: "500.00" } ],
      confirmation: true
    ).invoice
    @invoice = Billing::Issue.call(membership: @finance, invoice: draft, confirmation: true).invoice
  end

  test "client cannot see unreleased invoice and can see released invoice with download" do
    sign_in_as(@client_owner.user, membership: @client_owner)
    get client_invoices_path
    assert_response :success
    assert_no_match(@invoice.reference_number, response.body)

    Billing::Release.call(membership: @finance, invoice: @invoice, confirmation: true)

    get client_invoices_path
    assert_response :success
    assert_match(@invoice.reference_number, response.body)

    get client_invoice_path(@invoice)
    assert_response :success
    assert_match(/SIMULATED|not payable/i, response.body)

    get download_client_invoice_path(@invoice)
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "other client organisation cannot access released invoice" do
    Billing::Release.call(membership: @finance, invoice: @invoice, confirmation: true)
    other = create_other_client_membership!
    sign_in_as(other.user, membership: other)

    get client_invoice_path(@invoice)
    assert_response :not_found

    get download_client_invoice_path(@invoice)
    assert_response :not_found
  end

  private

    def create_finance_membership!
      user = User.create!(
        email: "finance-client-f408-#{SecureRandom.hex(4)}@example.test",
        password: "Password1!",
        password_confirmation: "Password1!",
        full_name: "Finance QA",
        status: "active"
      )
      Membership.create!(
        user: user,
        organization: organizations(:ant_marine),
        role_key: "staff.finance_officer",
        status: "active",
        accepted_at: Time.current
      )
    end

    def create_other_client_membership!
      user = User.create!(
        email: "other-client-bill-#{SecureRandom.hex(4)}@example.test",
        password: "Password1!",
        password_confirmation: "Password1!",
        full_name: "Other Client",
        status: "active"
      )
      Membership.create!(
        user: user,
        organization: organizations(:other_client),
        role_key: "client.org_owner",
        status: "active",
        accepted_at: Time.current
      )
    end

    def create_simulated_project!
      quote = approve_quote!(create_ready_quote)
      quote.update_columns(client_organization_id: organizations(:acme_client).id)
      release = Clients::ReleaseQuoteToPortal.call(
        actor_membership: @staff, quote: quote,
        quote_revision: quote.current_revision, client_organization: organizations(:acme_client)
      ).release
      decision = Commercial::QuoteDecision.call(
        membership: @client_owner, release: release, response: "accepted",
        confirmation: true, idempotency_key: "f408-client-#{SecureRandom.hex(4)}"
      )
      Delivery::CreateFromAcceptance.call(
        membership: @staff,
        quote_response: decision.response,
        attributes: { title: "Client billing project" },
        confirmation: true
      ).project
    end
end
