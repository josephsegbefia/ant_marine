# frozen_string_literal: true

require "test_helper"

class Notifications::StaffPublisherTest < ActiveSupport::TestCase
  include EnquiryTestHelper
  include ActionMailer::TestHelper

  test "a new enquiry notifies active staff who triage enquiries, once each, and never by email" do
    assert_no_emails do
      @inquiry = submit_enquiry!
    end
    recipients = StaffNotification.where(kind: "new_enquiry", subject_id: @inquiry.id).pluck(:recipient_membership_id)

    assert_includes recipients, memberships(:dual_staff).id
    assert_includes recipients, memberships(:ops_manager_membership).id
    refute_includes recipients, memberships(:staff_membership).id
    refute_includes recipients, memberships(:client_owner_membership).id
    assert_equal recipients.uniq.size, recipients.size

    notification = StaffNotification.find_by!(kind: "new_enquiry", recipient_membership_id: memberships(:dual_staff).id)
    assert_equal "New enquiry #{@inquiry.reference_number} from Harbour Logistics Ltd", notification.title
    refute_includes notification.title, "ama@harbour.example"
  end

  test "publishing the same event twice does not duplicate notifications" do
    inquiry = submit_enquiry!
    event = AuditEvent.find_by!(event_type: "service_inquiry.submitted", subject_id: inquiry.id)
    assert_no_difference -> { StaffNotification.count } do
      Notifications::StaffPublisher.new_enquiry(inquiry: inquiry, audit_event: event)
    end
  end

  test "assignment notifies the new assignee and the previous one, but never the person acting" do
    inquiry = submit_enquiry!
    surveyor = create_staff_member!
    assign_enquiry!(inquiry, surveyor)
    assert StaffNotification.exists?(kind: "enquiry_assigned", recipient_membership_id: surveyor.id, subject_id: inquiry.id)

    assign_enquiry!(inquiry, memberships(:ops_manager_membership), reason: "Handover")
    assert StaffNotification.exists?(kind: "enquiry_reassigned_away", recipient_membership_id: surveyor.id)
    assert StaffNotification.exists?(kind: "enquiry_assigned", recipient_membership_id: memberships(:ops_manager_membership).id)

    assign_enquiry!(inquiry, memberships(:dual_staff), reason: "I will take it", membership: memberships(:dual_staff))
    refute StaffNotification.exists?(kind: "enquiry_assigned", recipient_membership_id: memberships(:dual_staff).id)
  end

  test "suspended members are not notified" do
    memberships(:ops_manager_membership).update_columns(status: "suspended")
    inquiry = submit_enquiry!
    refute StaffNotification.exists?(subject_id: inquiry.id, recipient_membership_id: memberships(:ops_manager_membership).id)
  end

  test "a recorded client answer notifies the assignee" do
    inquiry = submit_enquiry!
    surveyor = create_staff_member!
    assign_enquiry!(inquiry, surveyor)
    clarification = Intake::InquiryClarifications.prepare!(inquiry: inquiry.reload, membership: memberships(:dual_staff),
                                                           subject: "IMO", questions: "IMO number?")
    Intake::InquiryClarifications.record_response!(clarification: clarification, membership: memberships(:dual_staff),
                                                   response_text: "1234567", source: "phone")
    notification = StaffNotification.find_by!(kind: "clarification_answered", recipient_membership_id: surveyor.id)
    refute_includes notification.title, "1234567"
  end

  test "only in-app events can be published" do
    inquiry = submit_enquiry!
    event = AuditEvent.last
    assert_raises(ArgumentError) do
      Notifications::StaffPublisher.publish([ memberships(:dual_staff) ], kind: "invitation.issued", inquiry: inquiry,
                                                                           audit_event: event, title: "x")
    end
  end
end
