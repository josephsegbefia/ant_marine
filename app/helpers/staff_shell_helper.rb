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
    ::Invitations::Policy::STAFF_ISSUER_ROLES.include?(Current.membership.role_key)
  end

  def staff_nav_active?(key)
    (content_for?(:staff_nav) ? content_for(:staff_nav) : "overview") == key.to_s
  end
end
