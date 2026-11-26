# frozen_string_literal: true

require "test_helper"

class Billing::ConcurrencyTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client_owner = memberships(:client_owner_membership)
    @finance = create_finance_membership!("a")
    @finance_b = create_finance_membership!("b")
    @project = create_simulated_project!(title: "Concurrency billing project")
  end

  test "concurrent issuance cannot exceed accepted billable capacity" do
    accepted = Billing::Capacity.accepted_total_cents(@project)
    currency = @project.commercial_snapshot["currency"]
    almost_all = Commercial::Money.to_input(accepted - 1, currency)

    draft_a = create_draft!(@finance, almost_all, "Concurrent A")
    # A reserves accepted-1 as a draft, leaving 1 cent. Create B at 1 cent, then bump it to 2
    # so concurrent issuance contends for overlapping capacity.
    draft_b = create_draft!(@finance_b, Commercial::Money.to_input(1, currency), "Concurrent B")
    draft_b.invoice_line_items.first.update_columns(unit_amount_cents: 2, line_total_cents: 2)
    draft_b.update_columns(total_cents: 2)

    issued = []
    errors = []
    mutex = Mutex.new
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          result = Billing::Issue.call(membership: @finance, invoice: draft_a, confirmation: true).invoice
          mutex.synchronize { issued << result }
        rescue StandardError => e
          mutex.synchronize { errors << e }
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          result = Billing::Issue.call(membership: @finance_b, invoice: draft_b, confirmation: true).invoice
          mutex.synchronize { issued << result }
        rescue StandardError => e
          mutex.synchronize { errors << e }
        end
      end
    ]
    threads.each(&:join)

    assert_operator issued.size, :>=, 1
    assert_operator Billing::Capacity.issued_committed_cents(@project.reload), :<=, accepted
    # At least one side must lose when both try to consume overlapping capacity.
    assert(issued.size == 1 || errors.any?)
    assert_equal accepted - 1, issued.first.total_cents if issued.size == 1 && errors.any?
  end

  test "concurrent payments cannot overpay a single invoice" do
    draft = create_draft!(@finance, "500.00", "Payment race")
    invoice = Billing::Issue.call(membership: @finance, invoice: draft, confirmation: true).invoice

    results = []
    errors = []
    mutex = Mutex.new
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          payment = Billing::RecordPayment.call(
            membership: @finance,
            invoice: invoice,
            attributes: { amount: "300.00", payment_on: Date.current, payment_method: "bank_transfer", external_reference: "RACE-1" }
          ).payment
          mutex.synchronize { results << payment }
        rescue StandardError => e
          mutex.synchronize { errors << e }
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          payment = Billing::RecordPayment.call(
            membership: @finance_b,
            invoice: invoice,
            attributes: { amount: "300.00", payment_on: Date.current, payment_method: "bank_transfer", external_reference: "RACE-2" }
          ).payment
          mutex.synchronize { results << payment }
        rescue StandardError => e
          mutex.synchronize { errors << e }
        end
      end
    ]
    threads.each(&:join)

    invoice.reload
    assert_operator invoice.net_paid_cents, :<=, invoice.total_cents
    assert_equal 2, results.size + errors.size
    assert(errors.any? || invoice.net_paid_cents <= invoice.total_cents)
  end

  test "duplicate reversal is rejected and balance stays consistent" do
    draft = create_draft!(@finance, "200.00", "Reversal race")
    invoice = Billing::Issue.call(membership: @finance, invoice: draft, confirmation: true).invoice
    payment = Billing::RecordPayment.call(
      membership: @finance,
      invoice: invoice,
      attributes: { amount: "200.00", payment_on: Date.current, payment_method: "cash", external_reference: "REV-1" }
    ).payment

    errors = []
    successes = 0
    mutex = Mutex.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Billing::ReversePayment.call(membership: @finance, invoice: invoice, payment: payment, reason: "QA race")
          mutex.synchronize { successes += 1 }
        rescue StandardError => e
          mutex.synchronize { errors << e }
        end
      end
    end
    threads.each(&:join)

    assert_equal 1, successes
    assert errors.any?
    assert_equal 20_000, invoice.reload.outstanding_cents
  end

  private

    def create_draft!(membership, amount, description)
      Billing::CreateDraft.call(
        membership: membership,
        project: @project,
        attributes: {
          description: description,
          issue_on: Date.current,
          due_on: Date.current + 14,
          payment_terms_text: "Simulated concurrency terms"
        },
        lines: [ { description: description, quantity: "1", unit: "Lot", unit_amount: amount } ],
        confirmation: true
      ).invoice
    end

    def create_finance_membership!(tag)
      user = User.create!(
        email: "finance-conc-#{tag}-#{SecureRandom.hex(3)}@example.test",
        password: "Password1!",
        password_confirmation: "Password1!",
        full_name: "Finance Conc #{tag}",
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

    def create_simulated_project!(title:)
      quote = approve_quote!(create_ready_quote)
      quote.update_columns(client_organization_id: organizations(:acme_client).id)
      release = Clients::ReleaseQuoteToPortal.call(
        actor_membership: @staff, quote: quote,
        quote_revision: quote.current_revision, client_organization: organizations(:acme_client)
      ).release
      decision = Commercial::QuoteDecision.call(
        membership: @client_owner, release: release, response: "accepted",
        confirmation: true, idempotency_key: "f409a-conc-#{SecureRandom.hex(4)}"
      )
      Delivery::CreateFromAcceptance.call(
        membership: @staff,
        quote_response: decision.response,
        attributes: { title: title },
        confirmation: true
      ).project
    end
end
