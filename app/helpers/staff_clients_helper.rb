# frozen_string_literal: true

module StaffClientsHelper
  def client_status_label(organization)
    organization.active? ? "Active" : "Archived"
  end

  def client_status_badge_variant(organization)
    organization.active? ? "ant-badge--good" : "ant-badge--muted"
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
