# frozen_string_literal: true

require "test_helper"

class Intake::InquiryClarificationsTest < ActiveSupport::TestCase
  include EnquiryTestHelper

  setup do
    @inquiry = submit_enquiry!
    @coordinator = memberships(:dual_staff)
    triage!(@inquiry, :start_review)
  end

  def prepare!(**overrides)
    Intake::InquiryClarifications.prepare!(
      inquiry: @inquiry.reload, membership: @coordinator,
      subject: "Vessel details", questions: "What is the vessel's IMO number?", **overrides
    )
  end

  test "preparing a request is internal and does not change the enquiry status" do
    clarification = prepare!(prepared_message: "Dear Ama, could you share the IMO number?")
    assert_equal "prepared", clarification.status
    assert_equal "Prepared — not sent to the client", clarification.status_label
    assert_equal @coordinator, clarification.created_by_membership
    assert_equal "under_review", @inquiry.reload.current_status
    assert AuditEvent.exists?(event_type: "service_inquiry.clarification_prepared", subject_id: @inquiry.id)
  end

  test "recording contact moves the enquiry to awaiting information; the answer moves it back" do
    clarification = prepare!
    Intake::InquiryClarifications.record_contact!(clarification: clarification, membership: @coordinator, channel: "phone")
    clarification.reload
    assert_equal "contacted_outside_system", clarification.status
    assert_equal @coordinator, clarification.contacted_by_membership
    assert_equal "needs_clarification", @inquiry.reload.current_status

    Intake::InquiryClarifications.record_response!(clarification: clarification, membership: @coordinator,
                                                   response_text: "IMO 1234567", source: "email",
                                                   received_on: Date.current.iso8601)
    clarification.reload
    assert_equal "answered", clarification.status
    assert_equal "IMO 1234567", clarification.response_text
    assert_equal "email", clarification.response_source
    assert_equal @coordinator, clarification.response_recorded_by_membership
    assert_equal "under_review", @inquiry.reload.current_status

    answered = AuditEvent.find_by!(event_type: "service_inquiry.clarification_answered", subject_id: @inquiry.id)
    refute_includes answered.metadata.to_json, "1234567"
  end

  test "the enquiry keeps waiting while another contacted request is unanswered" do
    first = prepare!
    second = prepare!(subject: "Dates")
    [ first, second ].each do |clarification|
      Intake::InquiryClarifications.record_contact!(clarification: clarification, membership: @coordinator, channel: "phone")
    end
    Intake::InquiryClarifications.record_response!(clarification: first.reload, membership: @coordinator,
                                                   response_text: "Answer", source: "phone")
    assert_equal "needs_clarification", @inquiry.reload.current_status

    Intake::InquiryClarifications.withdraw!(clarification: second.reload, membership: @coordinator)
    assert_equal "under_review", @inquiry.reload.current_status
    assert_equal "withdrawn", second.reload.status
  end

  test "an unanswered question blocks qualification until answered or withdrawn" do
    clarification = prepare!
    error = assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :qualify) }
    assert_match(/withdraw the open question/, error.message)

    Intake::InquiryClarifications.withdraw!(clarification: clarification, membership: @coordinator)
    triage!(@inquiry, :qualify)
    assert_equal "qualified", @inquiry.reload.current_status
  end

  test "invalid steps are refused" do
    clarification = prepare!
    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      Intake::InquiryClarifications.record_contact!(clarification: clarification, membership: @coordinator, channel: "sms_blast")
    end
    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      Intake::InquiryClarifications.record_response!(clarification: clarification, membership: @coordinator,
                                                     response_text: "x", source: "carrier pigeon")
    end
    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      Intake::InquiryClarifications.record_response!(clarification: clarification, membership: @coordinator,
                                                     response_text: "x", source: "phone", received_on: (Date.current + 1).iso8601)
    end
    Intake::InquiryClarifications.withdraw!(clarification: clarification, membership: @coordinator)
    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      Intake::InquiryClarifications.record_contact!(clarification: clarification.reload, membership: @coordinator, channel: "phone")
    end
    assert_raises(ActiveRecord::RecordInvalid) { prepare!(questions: "") }
  end

  test "closed enquiries cannot receive new requests" do
    triage!(@inquiry, :close, closure_reason: "cancelled")
    assert_raises(Intake::InquiryTransition::InvalidTransition) { prepare! }
  end

  test "people without qualify permission cannot manage clarifications" do
    surveyor = create_staff_member!
    assign_enquiry!(@inquiry, surveyor, reason: "Site visit")
    clarification = prepare!
    [ surveyor, memberships(:staff_membership), memberships(:client_owner_membership) ].each do |membership|
      assert_raises(Intake::InquiryTransition::NotAuthorized) do
        Intake::InquiryClarifications.prepare!(inquiry: @inquiry, membership: membership, subject: "x", questions: "y")
      end
      assert_raises(Intake::InquiryTransition::NotAuthorized) do
        Intake::InquiryClarifications.record_response!(clarification: clarification, membership: membership,
                                                       response_text: "x", source: "phone")
      end
    end
  end

  test "database requires attribution for each recorded step" do
    clarification = prepare!
    [ { status: "contacted_outside_system" }, { status: "answered", response_text: "x" }, { status: "withdrawn" } ].each do |columns|
      assert_raises(ActiveRecord::CheckViolation) do
        ServiceInquiry.transaction(requires_new: true) { clarification.update_columns(columns) }
      end
    end
  end
end
