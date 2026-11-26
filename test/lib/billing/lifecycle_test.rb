# frozen_string_literal: true

require "test_helper"

class Billing::LifecycleTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @finance = create_finance_membership!
    @surveyor = memberships(:staff_membership)
    @client_owner = memberships(:client_owner_membership)
    @project = create_simulated_project!
  end

  test "finance can create issue release pay reverse and void after clearing payments" do
    draft = Billing::CreateDraft.call(
      membership: @finance,
      project: @project,
      attributes: {
        description: "Partial simulated invoice",
        issue_on: Date.current,
        due_on: Date.current + 14,
        payment_terms_text: "Simulated terms only"
      },
      lines: [ { description: "Initial payment", quantity: "1", unit: "Lot", unit_amount: "1000.00" } ],
      confirmation: true
    ).invoice

    assert draft.draft?
    assert_equal 100_000, draft.total_cents

    issued = Billing::Issue.call(membership: @finance, invoice: draft, confirmation: true).invoice
    assert issued.issued?
    assert issued.storage_asset.present?
    pdf = Billing::PdfRenderer.render(invoice: issued)
    assert_operator pdf.bytesize, :>, 500
    assert_includes pdf.force_encoding("BINARY"), "53494d554c41".b # hex-encoded "SIMULA" from Prawn TJ array

    assert_raises(Billing::CreateDraft::InvalidState) do
      Billing::CreateDraft.call(
        membership: @finance,
        project: @project,
        attributes: { description: "Too much", issue_on: Date.current, due_on: Date.current + 7 },
        lines: [ { description: "Excess", quantity: "1", unit: "Lot",
                   unit_amount_cents: Billing::Capacity.accepted_total_cents(@project) } ],
        confirmation: true
      )
    end

    Billing::Release.call(membership: @finance, invoice: issued, confirmation: true)
    assert issued.reload.released_to_client?

    partial = Billing::RecordPayment.call(
      membership: @finance,
      invoice: issued,
      attributes: { amount: "400.00", payment_on: Date.current, payment_method: "bank_transfer", external_reference: "QA-PAY-1" }
    ).payment
    assert_equal 60_000, issued.reload.outstanding_cents
    assert_equal "partially_paid", issued.payment_status

    assert_raises(Billing::RecordPayment::InvalidState) do
      Billing::RecordPayment.call(
        membership: @finance,
        invoice: issued,
        attributes: { amount: "700.00", payment_on: Date.current, payment_method: "cash" }
      )
    end

    Billing::RecordPayment.call(
      membership: @finance,
      invoice: issued,
      attributes: { amount: "600.00", payment_on: Date.current, payment_method: "bank_transfer", external_reference: "QA-PAY-2" }
    )
    assert_equal 0, issued.reload.outstanding_cents
    assert_equal "paid", issued.payment_status

    Billing::ReversePayment.call(membership: @finance, invoice: issued, payment: partial, reason: "QA correction")
    assert_equal 40_000, issued.reload.outstanding_cents

    assert_raises(Billing::VoidInvoice::InvalidState) do
      Billing::VoidInvoice.call(membership: @finance, invoice: issued, reason: "too soon", confirmation: true)
    end

    remaining = issued.payment_records.reject(&:reversed?).first
    Billing::ReversePayment.call(membership: @finance, invoice: issued, payment: remaining, reason: "clear for void")
    release = issued.active_release
    Billing::RevokeRelease.call(membership: @finance, invoice: issued, release: release, reason: "void preparation")
    voided = Billing::VoidInvoice.call(membership: @finance, invoice: issued, reason: "QA void", confirmation: true).invoice
    assert voided.void?
  end

  test "surveyor without billing cannot manage invoices and other client cannot view" do
    draft = Billing::CreateDraft.call(
      membership: @finance,
      project: @project,
      attributes: { description: "Access test", issue_on: Date.current, due_on: Date.current + 7 },
      lines: [ { description: "Item", quantity: "1", unit: "Lot", unit_amount: "250.00" } ],
      confirmation: true
    ).invoice
    issued = Billing::Issue.call(membership: @finance, invoice: draft, confirmation: true).invoice
    Billing::Release.call(membership: @finance, invoice: issued, confirmation: true)

    refute Billing::Access.can_manage?(@surveyor, issued)
    refute Billing::Access.can_record_payment?(@surveyor, issued)
    assert Billing::Access.can_view_metadata?(@client_owner, issued.reload)
    refute Billing::Access.can_view_metadata?(create_other_client_membership!, issued)
  end

  test "issued invoice line items reject direct SQL mutation" do
    draft = Billing::CreateDraft.call(
      membership: @finance,
      project: @project,
      attributes: { description: "Immutability", issue_on: Date.current, due_on: Date.current + 7 },
      lines: [ { description: "Item", quantity: "1", unit: "Lot", unit_amount: "100.00" } ],
      confirmation: true
    ).invoice
    issued = Billing::Issue.call(membership: @finance, invoice: draft, confirmation: true).invoice
    line = issued.invoice_line_items.first

    error = assert_raises(ActiveRecord::StatementInvalid) do
      InvoiceLineItem.connection.execute("UPDATE invoice_line_items SET line_total_cents = 1 WHERE id = #{line.id}")
    end
    assert_match(/immutable|cannot/i, error.message)
  end

  private

    def create_finance_membership!
      user = User.create!(
        email: "finance-f408-#{SecureRandom.hex(4)}@example.test",
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
        email: "other-client-f408-#{SecureRandom.hex(4)}@example.test",
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
      staff = @staff
      client_org = organizations(:acme_client)
      quote = approve_quote!(create_ready_quote)
      quote.update_columns(client_organization_id: client_org.id)
      release = Clients::ReleaseQuoteToPortal.call(
        actor_membership: staff, quote: quote,
        quote_revision: quote.current_revision, client_organization: client_org
      ).release
      decision = Commercial::QuoteDecision.call(
        membership: @client_owner, release: release, response: "accepted",
        confirmation: true, idempotency_key: "f408-#{SecureRandom.hex(4)}"
      )
      Delivery::CreateFromAcceptance.call(
        membership: staff,
        quote_response: decision.response,
        attributes: {
          title: "F408 billing project",
          operational_description: "Simulated hull work",
          location: "Tema Port"
        },
        confirmation: true
      ).project
    end
end
