# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteDispatcherTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @sender = memberships(:dual_staff)
    @quote = approve_quote!(create_ready_quote)
    ActionMailer::Base.deliveries.clear
  end

  def prepare!(quote = @quote, membership: @sender)
    Commercial::QuoteDispatcher.prepare!(quote: quote, membership: membership, expected_version: expected_version_for(quote))
  end

  def dispatch!(delivery, membership: @sender)
    Commercial::QuoteDispatcher.dispatch!(quote: delivery.quote, membership: membership, delivery_id: delivery.id)
  end

  test "dispatch is never available in production and only with local adapters elsewhere" do
    assert Commercial::QuoteIssuance.dispatch_available?, "test adapter should allow local dispatch"
    refute Commercial::QuoteIssuance.available?, "manual mark-as-issued stays off"

    original_env = Rails.env
    Rails.env = "production"
    refute Commercial::QuoteIssuance.dispatch_available?
  ensure
    Rails.env = original_env if original_env
  end

  test "smtp adapter outside production is still refused" do
    original = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :smtp
    refute Commercial::QuoteIssuance.dispatch_available?
    assert_includes Commercial::QuoteDispatcher.blockers(quote: @quote, membership: @sender), Commercial::QuoteIssuance::DISPATCH_DISABLED_MESSAGE
  ensure
    ActionMailer::Base.delivery_method = original
  end

  test "prepare records the exact approved version and frozen recipient without sending" do
    delivery = prepare!

    assert_equal "prepared", delivery.status
    assert_equal @quote.current_revision, delivery.quote_revision
    assert_equal "ama@example.com", delivery.recipient_email
    assert_equal "Harbour Logistics Ltd", delivery.recipient_company
    assert_equal "test", delivery.delivery_adapter
    assert_equal "prepared", @quote.reload.delivery_state
    assert_equal "approved_for_issuance", @quote.status
    assert_empty ActionMailer::Base.deliveries
    assert_no_enqueued_jobs only: DeliverQuoteJob
  end

  test "test adapter success sends the frozen PDF, marks the version issued and stays truthful" do
    delivery = prepare!
    assert_enqueued_with(job: DeliverQuoteJob) { dispatch!(delivery) }
    assert_equal "queued", delivery.reload.status
    assert_equal "delivery_pending", @quote.reload.delivery_state

    perform_enqueued_jobs only: DeliverQuoteJob

    delivery.reload
    assert_equal "accepted_by_provider", delivery.status
    assert_equal 1, delivery.attempt_count
    assert delivery.accepted_at.present?
    assert delivery.provider_message_id.present?
    assert_nil delivery.confirmed_at
    assert_equal "Accepted by the test mail system — no real email was sent", delivery.status_label

    @quote.reload
    assert_equal "issued", @quote.status
    assert_equal "delivery_attempted", @quote.delivery_state
    refute_equal "delivered", @quote.delivery_state
    assert_equal "issued", @quote.current_revision.revision_status
    assert_equal @sender.id, @quote.current_revision.issued_by_membership_id

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "ama@example.com" ], mail.to
    assert_includes mail.subject, @quote.reference_number
    assert_equal 1, mail.attachments.size
    assert_equal "#{@quote.reference_number}-v1.pdf", mail.attachments.first.filename
    body = mail.text_part.body.to_s
    assert_no_match(/accept|http|download/i, body)
    assert_includes extract_pdf_text(mail.attachments.first.body.decoded), "Hull inspection for MV Example"
  end

  test "drafts, pending and unapproved versions cannot be prepared" do
    draft = create_ready_quote
    error = assert_raises(Commercial::QuoteDispatcher::Refused) { prepare!(draft) }
    assert_match(/Only an approved version/, error.message)

    pending = create_ready_quote
    Commercial::QuoteTransition.apply!(quote: pending, action: :submit_for_review, membership: @sender)
    assert_raises(Commercial::QuoteDispatcher::Refused) { prepare!(pending) }
  end

  test "a newer unapproved version is never sent in place of the approved one" do
    delivery = prepare!
    Commercial::QuoteDispatcher.cancel!(quote: @quote, membership: @sender, delivery_id: delivery.id)
    create_revision!(@quote.reload)

    assert_raises(Commercial::QuoteDispatcher::Refused) { prepare!(@quote.reload) }
    assert_raises(Commercial::QuoteDispatcher::Refused) { dispatch!(delivery.reload) }
    assert_empty ActionMailer::Base.deliveries
  end

  test "a version cannot be revised while it is prepared for sending" do
    prepare!
    assert_raises(Commercial::QuoteRevisionCreator::NotAllowed) { create_revision!(@quote.reload) }
  end

  test "expired versions and missing or invalid recipients are refused" do
    @quote.current_revision.update_columns(valid_until: Date.current - 1)
    assert_match(/expired/, assert_raises(Commercial::QuoteDispatcher::Refused) { prepare! }.message)

    other = approve_quote!(create_ready_quote)
    other.current_revision.update_columns(recipient_snapshot: other.current_revision.recipient_snapshot.merge("email" => "not-an-email"))
    assert_match(/not valid/, assert_raises(Commercial::QuoteDispatcher::Refused) { prepare!(other) }.message)

    third = approve_quote!(create_ready_quote)
    third.current_revision.update_columns(recipient_snapshot: third.current_revision.recipient_snapshot.except("email"))
    assert_match(/no recipient email/, assert_raises(Commercial::QuoteDispatcher::Refused) { prepare!(third) }.message)
  end

  test "archived client organisations are not valid recipients" do
    client = organizations(:acme_client)
    @quote.current_revision.update_columns(recipient_snapshot: @quote.current_revision.recipient_snapshot.merge("client_organization_id" => client.id))
    client.update_columns(status: "archived")
    assert_match(/no longer active/, assert_raises(Commercial::QuoteDispatcher::Refused) { prepare! }.message)
  end

  test "stale approval references are refused" do
    stale = expected_version_for(@quote)
    Quote.where(id: @quote.id).update_all("lock_version = lock_version + 1")
    assert_raises(Commercial::QuoteTransition::StaleVersion) do
      Commercial::QuoteDispatcher.prepare!(quote: @quote.reload, membership: @sender, expected_version: stale)
    end
  end

  test "people without send permission cannot prepare, send or cancel" do
    delivery = prepare!
    deny_permission!(memberships(:ops_manager_membership), "quotes.send")
    ops = memberships(:ops_manager_membership).reload

    assert_raises(Commercial::QuoteDispatcher::Refused) { dispatch!(delivery, membership: ops) }
    assert_raises(Commercial::QuoteDispatcher::Refused) do
      Commercial::QuoteDispatcher.cancel!(quote: @quote, membership: ops, delivery_id: delivery.id)
    end
    assert_raises(Commercial::QuoteDispatcher::Refused) { prepare!(approve_quote!(create_ready_quote), membership: memberships(:staff_membership)) }
  end

  test "the same version is never prepared or sent twice" do
    delivery = prepare!
    assert_raises(Commercial::QuoteDispatcher::Refused) { prepare! }

    dispatch!(delivery)
    dispatch!(delivery.reload)
    assert_enqueued_jobs 1, only: DeliverQuoteJob

    perform_enqueued_jobs only: DeliverQuoteJob
    DeliverQuoteJob.perform_now(delivery.id)
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal 1, delivery.reload.attempt_count
  end

  test "mail server refusal is recorded as failed and nothing is marked issued" do
    delivery = prepare!
    dispatch!(delivery)
    with_failing_mailer(Net::SMTPFatalError.new("550 mailbox unavailable")) { perform_enqueued_jobs only: DeliverQuoteJob }

    delivery.reload
    assert_equal "failed", delivery.status
    assert_match(/refused/, delivery.failure_reason)
    assert_equal "approved_for_issuance", @quote.reload.status
    assert_equal "delivery_failed", @quote.delivery_state
    assert_equal "approved", @quote.current_revision.revision_status

    # A failed attempt may be prepared again deliberately by a person.
    assert_equal "prepared", prepare!(@quote.reload).status
  end

  test "ambiguous errors become outcome unknown, block resending and are not retried" do
    delivery = prepare!
    dispatch!(delivery)
    with_failing_mailer(Net::ReadTimeout.new) { perform_enqueued_jobs only: DeliverQuoteJob }

    delivery.reload
    assert_equal "outcome_unknown", delivery.status
    assert_no_enqueued_jobs only: DeliverQuoteJob
    assert_raises(Commercial::QuoteDispatcher::Refused) { prepare!(@quote.reload) }
    assert_equal "approved_for_issuance", @quote.status
  end

  test "withdrawing while queued cancels the send" do
    delivery = prepare!
    dispatch!(delivery)
    Commercial::QuoteTransition.apply!(quote: @quote.reload, action: :withdraw, membership: memberships(:ops_manager_membership))
    perform_enqueued_jobs only: DeliverQuoteJob

    assert_equal "cancelled", delivery.reload.status
    assert_empty ActionMailer::Base.deliveries
  end

  test "sending a newer version supersedes the earlier issued version" do
    first_delivery = prepare!
    dispatch!(first_delivery)
    perform_enqueued_jobs only: DeliverQuoteJob
    first = @quote.reload.current_revision

    ops = memberships(:ops_manager_membership)
    create_revision!(@quote, membership: ops)
    Commercial::QuoteTransition.apply!(quote: @quote.reload, action: :submit_for_review, membership: ops)
    review_quote!(@quote, :approve, reviewer: @sender)
    assert_equal "issued", first.reload.revision_status, "outstanding offer stays until the new version is sent"

    second_delivery = prepare!(@quote.reload, membership: ops)
    dispatch!(second_delivery, membership: ops)
    perform_enqueued_jobs only: DeliverQuoteJob

    assert_equal "superseded", first.reload.revision_status
    assert_equal @quote.reload.current_revision, first.superseded_by_revision
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  test "delivery confirmed cannot be recorded without provider evidence" do
    delivery = prepare!
    assert_raises(ActiveRecord::StatementInvalid) { delivery.update_columns(status: "delivery_confirmed") }
  end

  private

    def with_failing_mailer(error)
      failing = Object.new
      failing.define_singleton_method(:deliver_now) { raise error }
      QuotesMailer.define_singleton_method(:quotation) { |*| failing }
      yield
    ensure
      QuotesMailer.singleton_class.send(:remove_method, :quotation) if QuotesMailer.singleton_methods(false).include?(:quotation)
    end
end
