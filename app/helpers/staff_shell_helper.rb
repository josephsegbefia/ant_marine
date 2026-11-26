# frozen_string_literal: true

module StaffShellHelper
  def staff_display_name
    Current.user.full_name.presence || Current.user.email.split("@").first.titleize
  end

  def staff_greeting_name
    name = Current.user.full_name.presence
    return name.split.first if name.present?

    Current.user.email.split("@").first.titleize
  end

  def staff_multiple_workspaces?
    Current.user.portal_eligible_memberships.size > 1
  end

  def staff_can_invite?
    return false unless Current.membership&.staff_domain?

    Authorization::EffectivePermissions.allowed?(
      membership: Current.membership,
      permission_key: "team.invite"
    )
  end

  def staff_can_manage_quotations?
    return false unless Current.membership&.staff_domain?

    Authorization::EffectivePermissions.allowed?(
      membership: Current.membership,
      permission_key: "quotes.view_all"
    )
  end

  def staff_can_view_projects?
    return false unless Current.membership&.staff_domain?

    Authorization::EffectivePermissions.allowed?(
      membership: Current.membership,
      permission_key: "projects.view_all"
    ) || Authorization::EffectivePermissions.allowed?(
      membership: Current.membership,
      permission_key: "projects.view_assigned"
    )
  end

  def staff_can_view_enquiries?
    return false unless Current.membership&.staff_domain?

    ServiceInquiryPolicy.new(Current.membership, ServiceInquiry).index?
  end

  def staff_can_manage_clients?
    return false unless Current.membership&.staff_domain?

    OrganizationPolicy.new(Current.membership, Organization).index?
  end

  def staff_unread_notification_count
    return 0 unless Current.membership&.staff_domain?

    @staff_unread_notification_count ||= StaffNotificationPolicy::Scope.new(Current.membership, StaffNotification).resolve.unread.count
  end

  def staff_can_view_inspections?
    staff_can_view_projects? && Current.membership&.staff_domain?
  end

  def staff_can_view_reports?
    staff_can_view_projects? && Current.membership&.staff_domain?
  end

  def staff_can_manage_website?
    return false unless Current.membership&.staff_domain?

    Authorization::EffectivePermissions.allowed?(
      membership: Current.membership,
      permission_key: "content.manage"
    ) || Authorization::EffectivePermissions.allowed?(
      membership: Current.membership,
      permission_key: "content.view_draft"
    )
  end

  def staff_nav_active?(key)
    (content_for?(:staff_nav) ? content_for(:staff_nav) : "overview") == key.to_s
  end

  def staff_stat_icon(key)
    {
      new_enquiries: "clipboard",
      assigned: "users",
      approvals: "file",
      unread: "mail",
      new: "clipboard",
      mine: "users",
      unassigned: "users",
      awaiting: "clock",
      ready: "check"
    }.fetch(key.to_sym, "chart")
  end

  def staff_notification_icon(kind)
    {
      "new_enquiry" => "clipboard",
      "enquiry_assigned" => "users",
      "enquiry_reassigned_away" => "users",
      "clarification_answered" => "mail",
      "quote_accepted" => "check",
      "quote_declined" => "check",
      "quote_changes_requested" => "check",
      "project_created" => "brief",
      "project_assigned" => "users",
      "project_assignment_changed" => "users",
      "task_assigned" => "clipboard",
      "schedule_confirmed" => "clock",
      "schedule_cancelled" => "clock",
      "project_update" => "mail",
      "document_uploaded" => "file",
      "document_review_required" => "file",
      "document_changes_requested" => "file",
      "document_approved" => "check",
      "document_released" => "file",
      "document_release_revoked" => "file",
      "upload_requested" => "clipboard",
      "inspection_assigned" => "clipboard",
      "inspection_submitted" => "clipboard",
      "report_review_required" => "file",
      "report_changes_requested" => "file",
      "report_approved" => "check",
      "report_released" => "file"
    }.fetch(kind.to_s, "mail")
  end
end
