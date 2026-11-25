# frozen_string_literal: true

module Staff
  class NotificationsController < BaseController
    PER_PAGE = 25

    def index
      authorize StaffNotification
      assign_staff_breadcrumb(crumbs: [], current: "Notifications")
      scope = policy_scope(StaffNotification)
      @filter = params[:show] == "unread" ? "unread" : "all"
      scope = scope.unread if @filter == "unread"
      @unread_count = policy_scope(StaffNotification).unread.count
      @pagination = Pagination.new(scope.recent_first, page: params[:page], per_page: PER_PAGE)
      @notifications = @pagination.records
    end

    def open
      notification = policy_scope(StaffNotification).find(params[:id])
      authorize notification
      notification.update!(read_at: Time.current) unless notification.read?

      inquiry = notification.subject_record
      if inquiry && ServiceInquiryPolicy.new(Current.membership, inquiry).show?
        redirect_to staff_service_inquiry_path(inquiry), status: :see_other
      else
        redirect_to staff_notifications_path, status: :see_other,
                                              alert: "You no longer have access to that enquiry."
      end
    end

    def mark_all_read
      authorize StaffNotification
      count = policy_scope(StaffNotification).unread.update_all(read_at: Time.current)
      redirect_to staff_notifications_path, status: :see_other,
                                            notice: count.zero? ? "Everything is already read." : "Marked #{count} as read."
    end
  end
end
