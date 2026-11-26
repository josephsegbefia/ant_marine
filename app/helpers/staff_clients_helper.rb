# frozen_string_literal: true

module StaffClientsHelper
  def client_status_label(organization)
    organization.active? ? "Active" : "Archived"
  end

  def client_status_badge_variant(organization)
    organization.active? ? "ant-badge--good" : "ant-badge--muted"
  end

  def client_portal_access_label(organization)
    parts = [ "#{organization.portal_member_count} active" ]
    pending = organization.pending_invitation_count
    parts << "#{pending} pending" if pending.positive?
    parts.join(" · ")
  end

  def client_filters_active?(filters, view: "all")
    view.to_s != "all" || filters[:q].present? || filters[:status].present?
  end

  def client_index_path_with(view: nil, **extras)
    opts = extras.compact
    opts[:view] = view if view.present? && view.to_s != "all"
    staff_clients_path(opts)
  end

  def client_empty_state_copy(view, filters_active)
    if filters_active
      [
        "Nothing matched",
        "Try a different name, reference or clear the current filters."
      ]
    else
      case view
      when "awaiting"
        [ "No organisations waiting for portal access", "Every active client already has at least one portal member." ]
      when "with_portal"
        [ "No portal-connected organisations yet", "Invite a client contact when you are ready to share quotations and files." ]
      when "pending_invites"
        [ "No pending invitations", "Invitations appear here until the recipient activates their access." ]
      else
        [
          "No client organisations yet",
          "Create a client organisation when you are ready to set up portal access for a company."
        ]
      end
    end
  end

  def membership_access_label(membership)
    case membership.status
    when "active" then "Active member"
    when "invited" then "Invitation accepted — activating"
    when "suspended" then "Suspended"
    when "removed" then "Revoked"
    else membership.status.humanize
    end
  end

  def invitation_access_label(invitation)
    case invitation.status
    when "pending"
      invitation.expired? ? "Invitation expired" : "Invitation pending activation"
    when "accepted" then "Activated"
    when "revoked" then "Invitation revoked"
    when "expired" then "Invitation expired"
    else invitation.status.humanize
    end
  end

  def client_portal_role_options(roles)
    roles.map { |key| [ RoleLabels.label(key), key ] }
  end

  def client_facing_enquiry_status(status)
    {
      "submitted" => "Received",
      "under_review" => "Under review",
      "needs_clarification" => "Waiting for information",
      "qualified" => "Ready for quotation",
      "unqualified" => "Closed — outside scope",
      "merged" => "Closed — duplicate",
      "closed" => "Closed"
    }.fetch(status, status.to_s.humanize)
  end
end
