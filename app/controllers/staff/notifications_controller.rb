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

      subject = notification.subject_record
      if subject.is_a?(ServiceInquiry) && ServiceInquiryPolicy.new(Current.membership, subject).show?
        redirect_to staff_service_inquiry_path(subject), status: :see_other
      elsif subject.is_a?(Quote) && QuotePolicy.new(Current.membership, subject).show?
        redirect_to edit_staff_quotation_path(subject), status: :see_other
      elsif subject.is_a?(Document) && DocumentPolicy.new(Current.membership, subject).show?
        redirect_to staff_project_document_path(subject.project, subject), status: :see_other
      elsif subject.is_a?(UploadRequest) && UploadRequestPolicy.new(Current.membership, subject).show?
        redirect_to staff_project_documents_path(subject.project), status: :see_other
      elsif subject.is_a?(Project) && ProjectPolicy.new(Current.membership, subject).show?
        redirect_to staff_project_path(subject), status: :see_other
      else
        redirect_to staff_notifications_path, status: :see_other,
                                              alert: "You no longer have access to that item."
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
