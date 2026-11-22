# frozen_string_literal: true

class InvitationPolicy < ApplicationPolicy
  def manage?
    return false unless allowed?("team.invite")

    ::Invitations::Policy.new(inviter_membership: membership).manage_allowed?(invitation: record)
  end

  def issue?
    return false unless allowed?("team.invite")

    organization = record.is_a?(Organization) ? record : record.organization
    role_key = record.is_a?(Hash) ? record[:role_key] : record.role_key
    ::Invitations::Policy.new(inviter_membership: membership).issue_allowed?(
      organization: organization,
      role_key: role_key
    )
  end
end
