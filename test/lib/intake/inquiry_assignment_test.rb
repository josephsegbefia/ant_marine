# frozen_string_literal: true

require "test_helper"

class Intake::InquiryAssignmentTest < ActiveSupport::TestCase
  include EnquiryTestHelper

  setup do
    @inquiry = submit_enquiry!
    @surveyor = create_staff_member!
  end

  test "assigning and reassigning keeps a complete history" do
    assign_enquiry!(@inquiry, @surveyor)
    assert_equal @surveyor, @inquiry.reload.assigned_membership

    assert_raises(Intake::InquiryTransition::InvalidTransition) { assign_enquiry!(@inquiry, memberships(:ops_manager_membership)) }
    assign_enquiry!(@inquiry, memberships(:ops_manager_membership), reason: "Kofi is on leave this week.")

    history = @inquiry.assignments.to_a
    assert_equal 2, history.size
    assert_nil history.first.previous_membership
    assert_equal @surveyor, history.first.new_membership
    assert_equal @surveyor, history.last.previous_membership
    assert_equal memberships(:ops_manager_membership), history.last.new_membership
    assert_equal memberships(:dual_staff), history.last.actor_membership
    assert_equal "Kofi is on leave this week.", history.last.reason
    assert history.last.readonly?
    assert_equal %w[service_inquiry.assigned service_inquiry.reassigned],
                 AuditEvent.where(subject_type: "ServiceInquiry", subject_id: @inquiry.id)
                           .where("event_type LIKE 'service_inquiry.%assigned'").order(:id).pluck(:event_type)
  end

  test "unassigning needs a reason" do
    assign_enquiry!(@inquiry, @surveyor)
    assert_raises(Intake::InquiryTransition::InvalidTransition) { assign_enquiry!(@inquiry, nil) }
    assign_enquiry!(@inquiry, nil, reason: "Back to the shared queue.")
    assert_nil @inquiry.reload.assigned_membership_id
    assert AuditEvent.exists?(event_type: "service_inquiry.unassigned", subject_id: @inquiry.id)
  end

  test "assigning the same person again is refused" do
    assign_enquiry!(@inquiry, @surveyor)
    assert_raises(Intake::InquiryTransition::InvalidTransition) { assign_enquiry!(@inquiry, @surveyor, reason: "again") }
  end

  test "only eligible active staff of the same organisation can be assigned" do
    suspended_membership = create_staff_member!(status: "suspended")
    suspended_user = create_staff_member!(user_status: "suspended")
    finance = create_staff_member!(role_key: "staff.finance_officer")
    general_denied = create_staff_member!(role_key: "staff.general_staff")
    deny_permission!(general_denied, "inquiries.view_assigned")

    targets = [ memberships(:client_owner_membership), memberships(:client_membership), suspended_membership,
                suspended_user, finance, general_denied.reload ]
    targets.each do |target|
      error = assert_raises(Intake::InquiryTransition::InvalidTransition, "#{target.role_key} should be refused") do
        assign_enquiry!(@inquiry, target)
      end
      assert_match(/active team member/, error.message)
    end

    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      Intake::InquiryAssignment.assign!(inquiry: @inquiry, membership: memberships(:dual_staff), assignee_id: "999999999",
                                        reason: nil, expected_lock_version: @inquiry.reload.lock_version)
    end
    assert_nil @inquiry.reload.assigned_membership_id
    assert_equal 0, @inquiry.assignments.count

    eligible = Intake::InquiryAssignment.eligible_memberships(organizations(:ant_marine))
    assert_includes eligible, @surveyor
    assert_includes eligible, memberships(:staff_membership)
    [ suspended_membership, suspended_user, finance, general_denied, memberships(:client_owner_membership) ].each do |target|
      refute_includes eligible, target
    end
  end

  test "only staff with qualify permission may assign" do
    [ @surveyor, memberships(:staff_membership), memberships(:client_owner_membership) ].each do |membership|
      assert_raises(Intake::InquiryTransition::NotAuthorized) { assign_enquiry!(@inquiry, @surveyor, membership: membership) }
    end
  end

  test "closed enquiries must be reopened before reassignment" do
    triage!(@inquiry, :close, closure_reason: "cancelled")
    assert_raises(Intake::InquiryTransition::InvalidTransition) { assign_enquiry!(@inquiry, @surveyor) }
  end

  test "a stale page cannot reassign" do
    stale = @inquiry.reload.lock_version
    assign_enquiry!(@inquiry, @surveyor)
    assert_raises(Intake::InquiryTransition::StaleVersion) do
      Intake::InquiryAssignment.assign!(inquiry: @inquiry, membership: memberships(:dual_staff),
                                        assignee_id: memberships(:ops_manager_membership).id, reason: "x",
                                        expected_lock_version: stale)
    end
    assert_equal @surveyor, @inquiry.reload.assigned_membership
  end

  test "assigned staff with view_assigned see only their enquiries" do
    other = submit_enquiry!
    assign_enquiry!(@inquiry, @surveyor)

    scope = ServiceInquiryPolicy::Scope.new(@surveyor, ServiceInquiry.all).resolve
    assert_equal [ @inquiry.id ], scope.pluck(:id)
    assert ServiceInquiryPolicy.new(@surveyor, @inquiry.reload).show?
    refute ServiceInquiryPolicy.new(@surveyor, other).show?
    refute ServiceInquiryPolicy.new(@surveyor, @inquiry).triage?
    refute ServiceInquiryPolicy.new(@surveyor, @inquiry).prepare_quotation?
    assert ServiceInquiryPolicy.new(@surveyor, @inquiry).note?

    assign_enquiry!(@inquiry, memberships(:ops_manager_membership), reason: "Handover")
    refute ServiceInquiryPolicy.new(@surveyor, @inquiry.reload).show?
  end
end
