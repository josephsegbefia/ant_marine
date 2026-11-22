# frozen_string_literal: true

module ClientShellHelper
  def client_display_name
    Current.user.full_name.presence || Current.user.email.split("@").first.titleize
  end

  def client_greeting_name
    name = Current.user.full_name.presence
    return name.split.first if name.present?

    Current.user.email.split("@").first.titleize
  end

  def client_org_initials
    name = Current.membership.organization.name
    parts = name.split(/\s+/)
    if parts.size >= 2
      parts.first(2).map { |w| w[0] }.join.upcase
    else
      name.first(2).upcase
    end
  end

  def client_multiple_workspaces?
    Current.user.portal_eligible_memberships.size > 1
  end

  def client_can_invite?
    return false unless Current.membership&.client_domain?

    Authorization::EffectivePermissions.allowed?(
      membership: Current.membership,
      permission_key: "team.invite"
    )
  end

  def client_nav_active?(key)
    (content_for?(:client_nav) ? content_for(:client_nav) : "home") == key.to_s
  end
end
