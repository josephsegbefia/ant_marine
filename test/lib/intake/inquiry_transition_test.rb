# frozen_string_literal: true

require "test_helper"

class Intake::InquiryTransitionTest < ActiveSupport::TestCase
  include EnquiryTestHelper

  setup { @inquiry = submit_enquiry! }

  test "starting the review moves a new enquiry to under review and assigns the reviewer" do
    triage!(@inquiry, :start_review)
    @inquiry.reload

    assert_equal "under_review", @inquiry.current_status
    assert @inquiry.review_started_at
    assert_equal memberships(:dual_staff), @inquiry.assigned_membership
    assert_equal 1, @inquiry.assignments.count
    event = AuditEvent.find_by!(event_type: "service_inquiry.start_review", subject_id: @inquiry.id)
    assert_equal({ "reference_number" => @inquiry.reference_number, "from_status" => "submitted", "to_status" => "under_review" },
                 event.metadata)
    assert AuditEvent.exists?(event_type: "service_inquiry.assigned", subject_id: @inquiry.id)
  end

  test "starting the review keeps an existing assignee" do
    surveyor = create_staff_member!
    assign_enquiry!(@inquiry, surveyor)
    triage!(@inquiry, :start_review)
    assert_equal surveyor, @inquiry.reload.assigned_membership
    assert_equal 1, @inquiry.assignments.count
  end

  test "qualifying records the time and optional note without a client organisation" do
    triage!(@inquiry, :start_review)
    triage!(@inquiry, :qualify, note: "Scope is clear; survey team available.")
    @inquiry.reload

    assert_equal "qualified", @inquiry.current_status
    assert @inquiry.qualified_at
    assert_equal "Scope is clear; survey team available.", @inquiry.qualification_note
    assert_nil @inquiry.client_organization_id
  end

  test "qualifying may link an existing active client organisation but never another one" do
    triage!(@inquiry, :qualify, client_organization_id: organizations(:acme_client).id)
    assert_equal organizations(:acme_client), @inquiry.reload.client_organization

    other = submit_enquiry!
    error = assert_raises(Intake::InquiryTransition::InvalidTransition) do
      triage!(other, :qualify, client_organization_id: organizations(:ant_marine).id)
    end
    assert_match(/active client organisation/, error.message)
    assert_equal "submitted", other.reload.current_status

    organizations(:other_client).update_columns(status: "archived")
    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      triage!(other, :qualify, client_organization_id: organizations(:other_client).id)
    end
  end

  test "closing needs a listed reason and an explanation for other" do
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :close, closure_reason: "accepted") }
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :close, closure_reason: "other") }
    assert_equal "submitted", @inquiry.reload.current_status

    triage!(@inquiry, :close, closure_reason: "not_proceeding")
    @inquiry.reload
    assert_equal "closed", @inquiry.current_status
    assert_equal "not_proceeding", @inquiry.closure_reason
    assert @inquiry.closed_at
  end

  test "outside scope needs an explanation" do
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :mark_outside_scope) }
    triage!(@inquiry, :mark_outside_scope, note: "We do not offer aircraft inspections.")
    assert_equal "unqualified", @inquiry.reload.current_status
    assert_equal "outside_scope", @inquiry.closure_reason
  end

  test "an enquiry with an open quotation cannot be closed until the quotation is withdrawn separately" do
    quote = Commercial::QuoteFromInquiry.call(inquiry: @inquiry, membership: memberships(:dual_staff)).quote

    %i[close mark_outside_scope].each do |action|
      error = assert_raises(Intake::InquiryTransition::InvalidTransition) do
        triage!(@inquiry, action, closure_reason: "cancelled", note: "No longer needed")
      end
      assert_match(/#{quote.reference_number} is still open/, error.message)
    end
    assert_equal "draft", quote.reload.status
    assert_equal "submitted", @inquiry.reload.current_status

    Commercial::QuoteTransition.apply!(quote: quote, action: :withdraw, membership: memberships(:dual_staff))
    triage!(@inquiry, :close, closure_reason: "cancelled")
    assert_equal "closed", @inquiry.reload.current_status
    assert_equal "withdrawn", quote.reload.status
  end

  test "reopening needs a reason, clears the closure and keeps it in the history" do
    triage!(@inquiry, :close, closure_reason: "other", note: "Client asked us to pause.")
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :reopen) }

    triage!(@inquiry, :reopen, reason: "Client asked us to continue.")
    @inquiry.reload
    assert_equal "under_review", @inquiry.current_status
    assert_nil @inquiry.closure_reason
    assert_nil @inquiry.closed_at

    event = AuditEvent.where(event_type: "service_inquiry.reopen", subject_id: @inquiry.id).last
    assert_equal "Client asked us to continue.", event.metadata["reason"]
    assert_equal({ "closure_reason" => "other", "closure_note" => "Client asked us to pause." }, event.metadata["previous_closure"])
  end

  test "invalid transitions are refused and change nothing" do
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :reopen, reason: "x") }
    triage!(@inquiry, :start_review)
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :start_review) }
    triage!(@inquiry, :qualify)
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :qualify) }
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :accept) }
    assert_raises(Intake::InquiryTransition::InvalidTransition) { triage!(@inquiry, :quotation_sent) }
    assert_equal "qualified", @inquiry.reload.current_status
  end

  test "only staff with qualify permission may change the status" do
    surveyor = create_staff_member!
    assign_enquiry!(@inquiry, surveyor)
    denied = [ surveyor, memberships(:staff_membership), memberships(:client_owner_membership) ]
    denied.each do |membership|
      assert_raises(Intake::InquiryTransition::NotAuthorized, "#{membership.role_key} should be refused") do
        triage!(@inquiry, :start_review, membership: membership)
      end
    end

    coordinator = memberships(:dual_staff)
    deny_permission!(coordinator, "inquiries.qualify")
    assert_raises(Intake::InquiryTransition::NotAuthorized) { triage!(@inquiry, :start_review, membership: coordinator.reload) }
    assert_equal "submitted", @inquiry.reload.current_status
  end

  test "suspended staff are refused" do
    membership = memberships(:ops_manager_membership)
    membership.user.update_columns(status: "suspended")
    assert_raises(Intake::InquiryTransition::NotAuthorized) { triage!(@inquiry, :start_review, membership: membership.reload) }
  end

  test "a stale page cannot change the status" do
    stale = @inquiry.reload.lock_version
    triage!(@inquiry, :start_review)

    assert_raises(Intake::InquiryTransition::StaleVersion) do
      Intake::InquiryTransition.apply!(inquiry: @inquiry, action: :qualify, membership: memberships(:dual_staff),
                                       expected_lock_version: stale)
    end
    assert_raises(Intake::InquiryTransition::StaleVersion) do
      Intake::InquiryTransition.apply!(inquiry: @inquiry, action: :qualify, membership: memberships(:dual_staff),
                                       expected_lock_version: nil)
    end
    assert_equal "under_review", @inquiry.reload.current_status
  end

  test "internal clarification steps are not offered as staff actions" do
    assert_equal %w[start_review qualify mark_outside_scope mark_duplicate close],
                 Intake::InquiryTransition.available_actions(@inquiry, memberships(:dual_staff))
    assert_empty Intake::InquiryTransition.available_actions(@inquiry, memberships(:staff_membership))
    triage!(@inquiry, :close, closure_reason: "cancelled")
    assert_equal %w[reopen], Intake::InquiryTransition.available_actions(@inquiry.reload, memberships(:dual_staff))
  end

  test "the original request is never overwritten" do
    triage!(@inquiry, :start_review)
    @inquiry.reload
    refute @inquiry.update(description: "Changed", company_name: "Other Ltd")
    assert_includes @inquiry.errors[:base], "The original request cannot be changed."
    assert_equal "Harbour Logistics Ltd", @inquiry.reload.company_name
  end

  test "database refuses closed states without a reason and duplicates without a canonical record" do
    [
      { current_status: "closed" },
      { current_status: "merged", closure_reason: "duplicate", closed_at: Time.current },
      { current_status: "merged", closure_reason: "duplicate", closed_at: Time.current, duplicate_of_id: @inquiry.id },
      { current_status: "unqualified", closure_reason: "outside_scope", closed_at: Time.current },
      { current_status: "closed", closure_reason: "duplicate", closed_at: Time.current }
    ].each do |columns|
      assert_raises(ActiveRecord::CheckViolation, columns.inspect) do
        ServiceInquiry.transaction(requires_new: true) { @inquiry.update_columns(columns) }
      end
    end
    assert_equal "submitted", @inquiry.reload.current_status
  end
end
