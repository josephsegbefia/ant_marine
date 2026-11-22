# frozen_string_literal: true

module InvitationsHelper
  def role_label(role_key)
    RoleLabels.label(role_key)
  end

  def invitation_status_label(status)
    RoleLabels.invitation_status(status)
  end

  def invitation_status_badge_class(status)
    case status
    when "pending"
      "ant-badge--warn"
    when "accepted"
      "ant-badge--good"
    when "revoked", "expired"
      "ant-badge--muted"
    else
      "ant-badge--muted"
    end
  end

  def invitation_sent_summary(invitation)
    parts = [ role_label(invitation.role_key) ]
    parts << "Sent #{l(invitation.created_at, format: :short)}"
    parts.join(" · ")
  end
end
