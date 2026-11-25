# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteRevisionCreatorTest < ActiveSupport::TestCase
  setup do
    @coordinator = memberships(:dual_staff)
    @ops = memberships(:ops_manager_membership)
  end

  test "new version copies content, starts as a draft and keeps the approved version intact" do
    quote = approve_quote!(create_ready_quote(lines: [ [ "Hull inspection", "2", "1250.00" ], [ "Mobilisation", "1", "300.00" ] ]))
    first = quote.current_revision
    first_snapshot = first.attributes.except("updated_at")
    first_lines = first.line_items.map { |item| item.attributes.except("updated_at") }

    second = create_revision!(quote, membership: @ops, reason: "Client asked to add a second dive day.")
    quote.reload

    assert_equal 2, second.version_number
    assert_equal "draft", second.revision_status
    assert_nil second.frozen_at
    assert_nil second.approved_by_membership_id
    assert_nil second.approved_at
    assert_equal({}, second.recipient_snapshot)
    assert_equal first, second.predecessor_revision
    assert_equal "Client asked to add a second dive day.", second.revision_reason
    assert_equal @ops, second.prepared_by_membership
    assert_equal [ @ops.id ], second.contributor_membership_ids
    assert_equal first.title, second.title
    assert_equal first.scope_description, second.scope_description
    assert_equal first.total_cents, second.total_cents
    assert_equal first.line_items.map(&:description), second.line_items.map(&:description)
    refute_equal first.line_items.map(&:id).sort, second.line_items.map(&:id).sort

    assert_equal "draft", quote.status
    assert_equal second, quote.current_revision
    assert quote.editable?

    first.reload
    assert_equal "approved", first.revision_status
    assert_equal first_snapshot, first.attributes.except("updated_at")
    assert_equal first_lines, first.line_items.map { |item| item.attributes.except("updated_at") }

    event = AuditEvent.where(event_type: "quote.revision_created", subject_id: quote.id).last
    assert_equal 2, event.metadata["version_number"]
    assert_equal 1, event.metadata["predecessor_version_number"]
  end

  test "expired validity is not carried into the new version" do
    quote = approve_quote!(create_ready_quote)
    with_history_protection_disabled do
      quote.current_revision.update_columns(valid_until: Date.current - 1)
    end
    assert_nil create_revision!(quote.reload).valid_until
  end

  test "editing the new version never changes the approved version" do
    quote = approve_quote!(create_ready_quote)
    first = quote.current_revision
    second = create_revision!(quote)
    second.update!(title: "Revised title")
    second.line_items.first.update!(unit_price: "9999.00")

    assert_equal "Hull inspection for MV Example", first.reload.title
    assert_equal 125_000, first.line_items.first.unit_price_cents
  end

  test "the new version requires an independent reviewer; approval is not inherited" do
    quote = approve_quote!(create_ready_quote)
    second = create_revision!(quote, membership: @ops)
    Commercial::QuoteTransition.apply!(quote: quote.reload, action: :submit_for_review, membership: @ops)

    # The original approver prepared version 2, so cannot approve it — not even as Super Admin.
    assert_raises(Commercial::QuoteTransition::SeparationRequired) { review_quote!(quote, :approve, reviewer: @ops) }
    review_quote!(quote, :approve, reviewer: @coordinator)

    assert_equal @coordinator.id, second.reload.approved_by_membership_id
    assert second.version_frozen?
  end

  test "approving a new version retires the earlier unsent approved version" do
    quote = approve_quote!(create_ready_quote)
    first = quote.current_revision
    second = create_revision!(quote, membership: @ops)
    Commercial::QuoteTransition.apply!(quote: quote.reload, action: :submit_for_review, membership: @ops)
    review_quote!(quote, :approve, reviewer: @coordinator)

    first.reload
    assert_equal "superseded", first.revision_status
    assert_equal second, first.superseded_by_revision
    assert first.superseded_at.present?
    assert_equal [ 1 ], AuditEvent.where(event_type: "quote.approve", subject_id: quote.id).last.metadata["superseded_version_numbers"]
  end

  test "an issued version stays the outstanding offer when a newer version is approved" do
    quote = mark_issued!(approve_quote!(create_ready_quote))
    first = quote.current_revision
    create_revision!(quote, membership: @ops)
    Commercial::QuoteTransition.apply!(quote: quote.reload, action: :submit_for_review, membership: @ops)
    review_quote!(quote, :approve, reviewer: @coordinator)

    assert_equal "issued", first.reload.revision_status
    assert_nil first.superseded_at
  end

  test "drafts, pending versions and withdrawn quotations cannot be revised" do
    draft = create_ready_quote
    assert_raises(Commercial::QuoteRevisionCreator::NotAllowed) { create_revision!(draft) }

    pending = create_ready_quote
    Commercial::QuoteTransition.apply!(quote: pending, action: :submit_for_review, membership: @coordinator)
    assert_raises(Commercial::QuoteRevisionCreator::NotAllowed) { create_revision!(pending) }

    withdrawn = approve_quote!(create_ready_quote)
    Commercial::QuoteTransition.apply!(quote: withdrawn, action: :withdraw, membership: @ops)
    assert_raises(Commercial::QuoteRevisionCreator::NotAllowed) { create_revision!(withdrawn) }
  end

  test "a reason is required" do
    quote = approve_quote!(create_ready_quote)
    error = assert_raises(Commercial::QuoteTransition::InvalidTransition) { create_revision!(quote, reason: " ") }
    assert_equal "Explain why a new version is needed.", error.message
  end

  test "stale version references are refused and create nothing" do
    quote = approve_quote!(create_ready_quote)
    stale = expected_version_for(quote)
    create_revision!(quote)
    quote = approve_quote!(quote.reload, preparer: @coordinator, reviewer: @ops)

    assert_no_difference -> { QuoteRevision.count } do
      assert_raises(Commercial::QuoteTransition::StaleVersion) do
        Commercial::QuoteRevisionCreator.create!(quote: quote, membership: @coordinator, reason: "Again", expected_version: stale)
      end
    end
  end

  test "people without quotation permission cannot create versions" do
    quote = approve_quote!(create_ready_quote)
    deny_permission!(@coordinator, "quotes.create")
    assert_raises(Commercial::QuoteTransition::NotAuthorized) { create_revision!(quote, membership: @coordinator) }
    assert_raises(Commercial::QuoteTransition::NotAuthorized) { create_revision!(quote, membership: memberships(:staff_membership)) }
  end

  test "version numbers stay unique and the database enforces lineage" do
    quote = approve_quote!(create_ready_quote)
    assert_raises(ActiveRecord::StatementInvalid) do
      quote.quote_revisions.insert_all!([ { version_number: 2, revision_status: "draft", currency: "GHS" } ])
    end
  end

  test "approved versions cannot be edited after a newer version exists" do
    quote = approve_quote!(create_ready_quote)
    first = quote.current_revision
    create_revision!(quote)
    refute first.reload.update(title: "Rewritten history")
    assert_includes first.errors[:base], QuoteRevision::FROZEN_MESSAGE
    assert_raises(ActiveRecord::RecordInvalid) { first.line_items.first.update!(description: "Changed") }
  end

  test "historical PDFs render the content of the version requested" do
    quote = approve_quote!(create_ready_quote)
    second = create_revision!(quote, membership: @ops)
    second.update!(title: "Revised hull inspection")
    quote.update!(prospective_client: quote.prospective_client.merge("company_name" => "Renamed Ltd"))

    first_text = extract_pdf_text(Commercial::QuotePdfRenderer.render(quote: quote.reload, revision: quote.quote_revisions.find_by(version_number: 1)))
    second_text = extract_pdf_text(Commercial::QuotePdfRenderer.render(quote: quote, revision: second.reload))

    assert_includes first_text, "Version 1"
    assert_includes first_text, "Hull inspection for MV Example"
    assert_includes first_text, "Harbour Logistics Ltd"
    assert_includes first_text, "APPROVED VERSION — NOT YET SENT TO THE CLIENT"
    assert_not_includes first_text, "Revised hull inspection"
    assert_not_includes first_text, "Renamed Ltd"

    assert_includes second_text, "Version 2"
    assert_includes second_text, "Revised hull inspection"
    assert_includes second_text, "DRAFT — NOT A FINAL OFFER"
  end
end
