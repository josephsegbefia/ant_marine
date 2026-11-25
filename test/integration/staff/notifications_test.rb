# frozen_string_literal: true

require "test_helper"

module Staff
  class NotificationsTest < ActionDispatch::IntegrationTest
    include SessionTestHelper
    include EnquiryTestHelper

    setup { @inquiry = submit_enquiry! }

    test "staff see their own notifications, open them and mark them read" do
      sign_in_as(memberships(:dual_staff).user)
      get staff_notifications_path
      assert_response :success
      assert_select ".staff-nav-button[aria-label=?]", "Notifications, 1 unread"
      assert_select ".staff-notification--unread .staff-notification__title", text: /#{@inquiry.reference_number}/

      notification = StaffNotification.find_by!(recipient_membership_id: memberships(:dual_staff).id)
      post open_staff_notification_path(notification)
      assert_redirected_to staff_service_inquiry_path(@inquiry)
      assert notification.reload.read?

      get staff_notifications_path(show: "unread")
      assert_select ".staff-notification", count: 0
      assert_select "h2", text: "You are all caught up"
    end

    test "mark all as read only touches the signed-in person's notifications" do
      sign_in_as(memberships(:dual_staff).user)
      post mark_all_read_staff_notifications_path
      assert_redirected_to staff_notifications_path
      assert StaffNotification.where(recipient_membership_id: memberships(:dual_staff).id).all?(&:read?)
      refute StaffNotification.find_by!(recipient_membership_id: memberships(:ops_manager_membership).id).read?
    end

    test "nobody can open another person's notification" do
      other = StaffNotification.find_by!(recipient_membership_id: memberships(:ops_manager_membership).id)
      sign_in_as(memberships(:dual_staff).user)
      post open_staff_notification_path(other)
      assert_response :not_found
      refute other.reload.read?
    end

    test "opening a notification for an enquiry you can no longer see does not reveal it" do
      surveyor = create_staff_member!
      assign_enquiry!(@inquiry, surveyor)
      assign_enquiry!(@inquiry, memberships(:ops_manager_membership), reason: "Handover")
      notification = StaffNotification.find_by!(recipient_membership_id: surveyor.id, kind: "enquiry_assigned")

      sign_in_as(surveyor.user)
      post open_staff_notification_path(notification)
      assert_redirected_to staff_notifications_path
      assert_equal "You no longer have access to that item.", flash[:alert]
    end

    test "clients and anonymous visitors cannot reach notifications" do
      get staff_notifications_path
      assert_redirected_to new_session_path

      sign_in_as(memberships(:client_owner_membership).user)
      get staff_notifications_path
      assert_response :redirect
      assert_no_match %r{/staff/notifications}, response.location.to_s
    end

    test "notifications paginate" do
      30.times { submit_enquiry! }
      sign_in_as(memberships(:dual_staff).user)
      get staff_notifications_path
      assert_select ".staff-notification", count: 25
      assert_select ".ant-pagination__summary", text: /Showing 1–25 of 31 notifications/
      get staff_notifications_path(page: 2)
      assert_select ".staff-notification", count: 6
      get staff_notifications_path(page: "999")
      assert_select ".ant-pagination__page", text: "Page 2 of 2"
    end
  end
end
