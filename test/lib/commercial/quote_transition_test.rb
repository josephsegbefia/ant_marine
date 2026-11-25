# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteTransitionTest < ActiveSupport::TestCase
  setup do
    @coordinator = memberships(:dual_staff)
    @ops = memberships(:ops_manager_membership)
    @general = memberships(:staff_membership)
  end

  def apply(quote, action, membership = @coordinator, reason: nil)
    expected = %w[approve return_for_correction].include?(action.to_s) ? expected_version_for(quote) : nil
    Commercial::QuoteTransition.apply!(quote: quote, action: action, membership: membership, reason: reason, expected_version: expected)
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
    quote.current_revision.update_columns(revision_status: "pending_review")
    assert_raises(Commercial::QuoteTransition::NotReady) { apply(quote, :approve, @ops) }
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
    assert_equal @ops.id, revision.approved_by_membership_id
    assert_equal @coordinator.id, revision.prepared_by_membership_id
    assert_equal @coordinator.id, revision.submitted_by_membership_id
    assert_equal "not_prepared", quote.delivery_state
    event = AuditEvent.find_by!(subject_id: quote.id, event_type: "quote.approve")
    assert_equal @coordinator.id, event.metadata["prepared_by_membership_id"]
    assert_equal revision.id, event.metadata["revision_id"]
  end

  test "only reviewers with approval permission can approve" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)

    assert_raises(Commercial::QuoteTransition::NotAuthorized) { apply(quote, :approve, @general) }

    deny_permission!(@ops, "quotes.approve")
    reviewer = Membership.find(@ops.id)
    error = assert_raises(Commercial::QuoteTransition::NotAuthorized) { apply(quote.reload, :approve, reviewer) }
    assert_equal "You do not have permission to do that.", error.message
    assert_equal "pending_review", quote.reload.status

    apply(quote, :approve, memberships(:super_admin_membership))
    assert_equal "approved_for_issuance", quote.reload.status
  end

  test "the preparer cannot approve their own version even with approval permission" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)
    assert QuotePolicy.new(@coordinator, quote.reload).review?
    assert_not QuotePolicy.new(@coordinator, quote).approve?
    assert QuotePolicy.new(@coordinator, quote).another_reviewer_required?

    assert_difference -> { AuditEvent.where(event_type: "quote.approval_refused").count }, 1 do
      assert_raises(Commercial::QuoteTransition::SeparationRequired) { apply(quote, :approve, @coordinator) }
    end
    quote.reload
    assert_equal "pending_review", quote.status
    assert_nil quote.current_revision.frozen_at
    assert_nil quote.current_revision.approved_by_membership_id
  end

  test "a super administrator cannot approve a version they prepared" do
    admin = memberships(:super_admin_membership)
    quote = create_ready_quote(membership: admin)
    apply(quote, :submit_for_review, admin)
    assert_raises(Commercial::QuoteTransition::SeparationRequired) { apply(quote, :approve, admin) }
    assert_equal "pending_review", quote.reload.status

    apply(quote, :approve, @ops)
    assert_equal "approved_for_issuance", quote.reload.status
  end

  test "someone who submitted or edited the version cannot approve it" do
    quote = create_ready_quote
    apply(quote, :submit_for_review, @ops)
    assert_raises(Commercial::QuoteTransition::SeparationRequired) { apply(quote, :approve, @ops) }

    quote2 = create_ready_quote
    quote2.current_revision.tap { |r| r.record_contributor(@ops) }.save!
    apply(quote2, :submit_for_review)
    assert_raises(Commercial::QuoteTransition::SeparationRequired) { apply(quote2, :approve, @ops) }
    apply(quote2, :approve, memberships(:super_admin_membership))
    assert_equal "approved_for_issuance", quote2.reload.status
  end

  test "separation is evaluated for the specific version under review" do
    quote = create_ready_quote
    first = quote.current_revision
    second = quote.quote_revisions.create!(
      version_number: 2, title: first.title, scope_description: first.scope_description,
      deliverables: first.deliverables, exclusions: first.exclusions, currency: "GHS",
      valid_until: first.valid_until, payment_terms: first.payment_terms,
      prepared_by_membership: @ops, contributor_membership_ids: [ @ops.id ]
    )
    second.line_items.create!(description: "Inspection", quantity: 1, unit: "each", unit_price: "100.00")
    second.save!
    quote.update!(current_revision: second)

    apply(quote, :submit_for_review, @ops)
    assert_raises(Commercial::QuoteTransition::SeparationRequired) { apply(quote, :approve, @ops) }

    # The person who prepared version 1 did not prepare version 2, so may approve it.
    apply(quote, :approve, @coordinator)
    assert_equal @coordinator.id, second.reload.approved_by_membership_id
    assert_nil first.reload.approved_by_membership_id
  end

  test "a version with no recorded preparer cannot be approved" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)
    quote.current_revision.update_columns(prepared_by_membership_id: nil, submitted_by_membership_id: nil, contributor_membership_ids: [])
    error = assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(quote.reload, :approve, @ops) }
    assert_equal Commercial::QuoteTransition::UNATTRIBUTED_MESSAGE, error.message
    assert_not QuotePolicy.new(@ops, quote).approve?
  end

  test "reviewer actions must name the current version" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)
    current = expected_version_for(quote)

    [ nil, {}, current.merge(lock_version: current[:lock_version] - 1), current.merge(revision_id: 0) ].each do |expected|
      assert_raises(Commercial::QuoteTransition::StaleVersion) do
        Commercial::QuoteTransition.apply!(quote: quote, action: :approve, membership: @ops, expected_version: expected)
      end
    end
    assert_raises(Commercial::QuoteTransition::StaleVersion) do
      Commercial::QuoteTransition.apply!(quote: quote, action: :return_for_correction, membership: @ops, reason: "x")
    end
    assert_equal "pending_review", quote.reload.status

    Commercial::QuoteTransition.apply!(quote: quote, action: :approve, membership: @ops, expected_version: current)
    assert_equal "approved_for_issuance", quote.reload.status
  end

  test "a reviewer who opened an earlier submission cannot approve the resubmitted version unseen" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)
    seen = expected_version_for(quote)
    apply(quote, :return_for_correction, @ops, reason: "Update the price")
    apply(quote, :submit_for_review)

    assert_raises(Commercial::QuoteTransition::StaleVersion) do
      Commercial::QuoteTransition.apply!(quote: quote, action: :approve, membership: memberships(:super_admin_membership), expected_version: seen)
    end
    assert_equal "pending_review", quote.reload.status
  end

  test "suspended people cannot approve" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)
    users(:ops_manager).update_columns(status: "suspended")
    assert_raises(Commercial::QuoteTransition::NotAuthorized) { apply(quote, :approve, Membership.find(@ops.id)) }
    assert_equal "pending_review", quote.reload.status
  end

  test "the database refuses an approver who prepared the version" do
    quote = create_ready_quote
    revision = quote.current_revision
    assert_raises(ActiveRecord::StatementInvalid) do
      revision.update_columns(approved_by_membership_id: @coordinator.id)
    end
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

    apply(quote, :approve, @ops)
    assert_equal "approved_for_issuance", quote.reload.status
  end

  test "duplicate transitions are rejected with a clear message" do
    quote = create_ready_quote
    apply(quote, :submit_for_review)
    error = assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(quote, :submit_for_review) }
    assert_equal "This quotation is already waiting for review.", error.message

    apply(quote, :approve, @ops)
    error = assert_raises(Commercial::QuoteTransition::InvalidTransition) { apply(quote, :approve, @ops) }
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
