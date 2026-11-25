# frozen_string_literal: true

require "test_helper"

class Intake::DuplicatesAndTimelineTest < ActiveSupport::TestCase
  include EnquiryTestHelper

  setup do
    @original = submit_enquiry!
    @repeat = submit_enquiry!(company_name: "HARBOUR LOGISTICS LTD", contact_email: "other@harbour.example")
    @unrelated = submit_enquiry!(company_name: "Unrelated Co", contact_email: "someone@unrelated.example")
  end

  test "possible duplicates are suggested by email or company within the viewer's scope" do
    candidates = Intake::DuplicateFinder.candidates(@repeat, memberships(:dual_staff))
    assert_includes candidates, @original
    refute_includes candidates, @unrelated
    refute_includes candidates, @repeat

    surveyor = create_staff_member!
    assert_empty Intake::DuplicateFinder.candidates(@repeat, surveyor)
  end

  test "marking a duplicate links the canonical enquiry without changing either original request" do
    triage!(@repeat, :mark_duplicate, duplicate_reference: @original.reference_number.downcase)
    @repeat.reload

    assert_equal "merged", @repeat.current_status
    assert_equal @original, @repeat.duplicate_of
    assert_equal "duplicate", @repeat.closure_reason
    assert_equal "HARBOUR LOGISTICS LTD", @repeat.company_name
    assert_equal "other@harbour.example", @repeat.contact_email
    assert_includes @original.reload.duplicates, @repeat
    assert_equal "submitted", @original.current_status
  end

  test "duplicate marking refuses self, unknown, chained and guarded records" do
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@repeat, :mark_duplicate) }
    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      triage!(@repeat, :mark_duplicate, duplicate_reference: @repeat.reference_number)
    end
    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      triage!(@repeat, :mark_duplicate, duplicate_reference: "ANT-ENQ-1999-99999")
    end

    triage!(@repeat, :mark_duplicate, duplicate_reference: @original.reference_number)
    error = assert_raises(Intake::InquiryTransition::InvalidTransition) do
      triage!(@unrelated, :mark_duplicate, duplicate_reference: @repeat.reference_number)
    end
    assert_match(/itself a duplicate/, error.message)
  end

  test "an enquiry with an open quotation cannot be marked duplicate, so quotations are never moved" do
    quote = Commercial::QuoteFromInquiry.call(inquiry: @repeat, membership: memberships(:dual_staff)).quote
    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      triage!(@repeat, :mark_duplicate, duplicate_reference: @original.reference_number)
    end
    assert_equal @repeat, quote.reload.service_inquiry
  end

  test "reopening a duplicate removes the link but keeps it in the history" do
    triage!(@repeat, :mark_duplicate, duplicate_reference: @original.reference_number)
    triage!(@repeat, :reopen, reason: "Different vessel after all.")
    @repeat.reload
    assert_nil @repeat.duplicate_of_id
    event = AuditEvent.where(event_type: "service_inquiry.reopen", subject_id: @repeat.id).last
    assert_equal @original.reference_number, event.metadata.dig("previous_closure", "duplicate_of_reference")
  end

  test "the timeline lists only real events in plain English, newest first, with quotation progress" do
    coordinator = memberships(:dual_staff)
    triage!(@original, :start_review)
    Intake::InquiryNotes.add!(inquiry: @original.reload, membership: coordinator, body: "Confidential pricing hint")
    clarification = Intake::InquiryClarifications.prepare!(inquiry: @original, membership: coordinator,
                                                           subject: "IMO", questions: "IMO number?")
    Intake::InquiryClarifications.record_contact!(clarification: clarification, membership: coordinator, channel: "phone")
    Intake::InquiryClarifications.record_response!(clarification: clarification.reload, membership: coordinator,
                                                   response_text: "IMO 1234567", source: "phone")
    triage!(@original, :qualify)
    quote = Commercial::QuoteFromInquiry.call(inquiry: @original.reload, membership: coordinator).quote
    Commercial::QuoteTransition.apply!(quote: quote, action: :withdraw, membership: coordinator)

    entries = Intake::InquiryTimeline.entries(@original.reload)
    titles = entries.map(&:title)

    assert_equal "Quotation #{quote.reference_number} withdrawn", titles.first
    assert_equal "Enquiry received through the website", titles.last
    expected = [
      "Review started", "Assigned to #{coordinator.user.full_name.presence || coordinator.user.email}",
      "Internal note added", "Clarification request prepared (not sent)",
      "Client contacted outside this system (phone call)", "Waiting for information from the client",
      "Client’s answer recorded (received by phone call)", "Marked ready to quote",
      "Quotation #{quote.reference_number} started"
    ]
    expected.each { |title| assert_includes titles, title }
    assert_nil entries.last.actor_name
    rendered = entries.map { |entry| [ entry.title, entry.detail ].join(" ") }.join("\n")
    refute_match(/Confidential pricing hint|1234567|\{|ama@harbour/, rendered)
  end

  test "test-mode delivery is never described as a real send" do
    AuditEvent.record!(event_type: "quote.delivery_accepted", organization: @original.organization,
                       subject: Commercial::QuoteFromInquiry.call(inquiry: @original, membership: memberships(:dual_staff)).quote,
                       metadata: { reference_number: "ANT-Q-TEST", version_number: 1, delivery_adapter: "file" })
    AuditEvent.record!(event_type: "quote.approval_refused", organization: @original.organization,
                       subject: @original.quotes.first, metadata: { reference_number: "ANT-Q-TEST" })

    titles = Intake::InquiryTimeline.entries(@original).map(&:title)
    assert_includes titles, "Quotation ANT-Q-TEST version 1 sent in test mode — no real email was sent"
    refute(titles.any? { |title| title.include?("refused") })
  end
end
