# frozen_string_literal: true

require "test_helper"

class Staff::BillingTest < ActionDispatch::IntegrationTest
  setup do
    @staff = memberships(:ops_manager_membership)
    @client_owner = memberships(:client_owner_membership)
    @client_org = organizations(:acme_client)
    quote = approve_quote!(create_ready_quote)
    quote.update_columns(client_organization_id: @client_org.id)
    release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @staff, quote: quote,
      quote_revision: quote.current_revision, client_organization: @client_org
    ).release
    decision = Commercial::QuoteDecision.call(
      membership: @client_owner, release: release, response: "accepted",
      confirmation: true, idempotency_key: "f408-int-#{SecureRandom.hex(4)}"
    )
    @project = Delivery::CreateFromAcceptance.call(
      membership: @staff,
      quote_response: decision.response,
      attributes: { title: "Billing integration project" },
      confirmation: true
    ).project
    sign_in_as(users(:ops_manager), membership: @staff)
  end

  test "staff can open finance workspace and create a draft invoice" do
    get staff_finance_path
    assert_response :success
    assert_match(/Bills & balances|Simulated finance/i, response.body)

    get new_staff_invoice_path(project_id: @project.id)
    assert_response :success

    currency = @project.commercial_snapshot["currency"]
    amount = Commercial::Money.to_input(
      [ Billing::Capacity.remaining_billable_cents(@project, include_drafts: true), 50_000 ].min,
      currency
    )

    assert_difference -> { Invoice.count }, 1 do
      post staff_invoices_path, params: {
        project_id: @project.id,
        confirm: "1",
        invoice: {
          description: "Integration draft",
          issue_on: Date.current.iso8601,
          due_on: (Date.current + 10).iso8601,
          payment_terms_text: "Simulated terms",
          lines: [ { description: "Partial billing", quantity: "1", unit: "Lot", unit_amount: amount } ]
        }
      }
    end
    invoice = Invoice.order(:id).last
    assert_redirected_to staff_invoice_path(invoice)
    follow_redirect!
    assert_match(/SIMULATED|Draft/i, response.body)
    assert_match(invoice.reference_number, response.body)
  end
end
