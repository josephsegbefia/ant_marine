# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteTransitionTest < ActiveSupport::TestCase
  setup do
    @coordinator = memberships(:dual_staff)
    @ops = memberships(:ops_manager_membership)
    @general = memberships(:staff_membership)
  end

  def apply(quote, action, membership = @coordinator, reason: nil)
    Commercial::QuoteTransition.apply!(quote: quote, action: action, membership: membership, reason: reason)
  end

  test "submit_for_review moves a complete draft to pending review and is audited" do
    quote = create_ready_quote
    assert_difference -> { AuditEvent.where(event_type: "quote.submit_for_review").count }, 1 do
      apply(quote, :submit_for_review)
    end
    assert_equal "pending_review", quote.reload.status
    assert_equal "pending_review", quote.current_revision.revision_status
    assert_not quote.editable?
  end

  test "an empty or incomplete quotation cannot be submitted" do
    quote = create_draft_quote
    error = assert_raises(Commercial::QuoteTransition::NotReady) { apply(quote, :submit_for_review) }
    assert error.issues.any?
    assert_equal "draft", quote.reload.status
    assert_equal 0, AuditEvent.where(event_type: "quote.submit_for_review").count
  end

  test "an incomplete quotation cannot be approved even if it reached review" do
    quote = create_draft_quote
    quote.update_columns(status: "pending_review")
    assert_raises(Commercial::QuoteTransition::NotReady) { apply(quote, :approve) }
    assert_equal "pending_review", quote.reload.status
    assert_nil quote.current_revision.frozen_at
  end

  test "approve freezes the version and snapshots the recipient" do
    quote = approve_quote!(create_ready_quote)
    revision = quote.current_revision
    assert_equal "approved_for_issuance", quote.status
    assert revision.version_frozen?
    assert_equal "approved", revision.revision_status
    assert_equal "Harbour Logistics Ltd", revision.recipient_snapshot["company_name"]
    assert_equal "ama@example.com", revision.recipient_snapshot["email"]
    assert_equal @coordinator.id, revision.approved_by_membership_id
    assert_equal "not_prepared", quote.delivery_state
  end

  test "only reviewers with approval permission can approve" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)

    assert_raises(Commercial::QuoteTransition::NotAuthorized) { apply(quote, :approve, @general) }

    deny_permission!(@coordinator, "quotes.approve")
    preparer = Membership.find(@coordinator.id)
    assert_raises(Commercial::QuoteTransition::NotAuthorized) { apply(quote.reload, :approve, preparer) }
    assert_equal "pending_review", quote.reload.status

    apply(quote, :approve, @ops)
    assert_equal "approved_for_issuance", quote.reload.status
  end

  test "return for correction requires approval permission in both policy and transition" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)
    deny_permission!(@coordinator, "quotes.approve")
    preparer = Membership.find(@coordinator.id)

    assert_not QuotePolicy.new(preparer, quote.reload).return_for_correction?
    assert_raises(Commercial::QuoteTransition::NotAuthorized) do
      apply(quote, :return_for_correction, preparer, reason: "Fix the price")
    end
    assert_equal "pending_review", quote.reload.status
  end

  test "return for correction needs a reason and reopens editing" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)

    assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(quote, :return_for_correction, @ops, reason: "  ") }

    apply(quote.reload, :return_for_correction, @ops, reason: "Please split the mobilisation cost.")
    quote.reload
    assert_equal "returned_for_correction", quote.status
    assert_equal "draft", quote.current_revision.revision_status
    assert quote.editable?
    assert_equal "Please split the mobilisation cost.", quote.latest_correction_request.metadata["reason"]

    apply(quote, :submit_for_review)
    assert_equal "pending_review", quote.reload.status
  end

  test "duplicate transitions are rejected with a clear message" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)
    error = assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(quote, :submit_for_review) }
    assert_equal "This quotation is already waiting for review.", error.message

    apply(quote, :approve)
    error = assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(quote, :approve) }
    assert_equal "This quotation has already been approved.", error.message
    assert_equal 1, AuditEvent.where(subject_id: quote.id, event_type: "quote.approve").count
  end

  test "a stale in-memory quote cannot repeat a transition already applied elsewhere" do
    quote = create_ready_quote
    stale_copy = Quote.find(quote.id)
    apply(quote, :submit_for_review)
    assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(stale_copy, :submit_for_review) }
  end

  test "issuing is gated and never claims delivery" do
    quote = approve_quote!(create_ready_quote)
    error = assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(quote, :issue, @ops) }
    assert_equal Commercial::QuoteIssuance::UNAVAILABLE_MESSAGE, error.message
    quote.reload
    assert_equal "approved_for_issuance", quote.status
    assert_equal "not_prepared", quote.delivery_state
    assert_nil quote.current_revision.issued_at
  end

  test "withdraw requires permission and works from approved" do
    quote = approve_quote!(create_ready_quote)
    assert_raises(Commercial::QuoteTransition::NotAuthorized) { apply(quote, :withdraw, @general) }
    apply(quote, :withdraw)
    assert_equal "withdrawn", quote.reload.status
    assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(quote, :withdraw) }
  end

  test "unknown actions are rejected" do
    assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(create_draft_quote, :send_now) }
  end
end
