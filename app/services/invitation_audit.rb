# frozen_string_literal: true

class InvitationAudit
  def self.issued(invitation:, actor_membership:)
    record("invitation.issued", invitation: invitation, actor_membership: actor_membership)
  end

  def self.reissued(invitation:, actor_membership:)
    record("invitation.reissued", invitation: invitation, actor_membership: actor_membership)
  end

  def self.revoked(invitation:, actor_membership:)
    record("invitation.revoked", invitation: invitation, actor_membership: actor_membership)
  end

  def self.accepted(invitation:, actor_membership: nil, user:)
    record(
      "invitation.accepted",
      invitation: invitation,
      actor_membership: actor_membership,
      metadata: {
        "accepted_by_user_id" => user.id,
        "role_key" => invitation.role_key,
        "email" => invitation.email
      }
    )
  end

  def self.denied(actor_membership: nil, organization: nil, metadata: {})
    AuditEvent.record!(
      event_type: "invitation.denied",
      organization: organization,
      actor_membership: actor_membership,
      metadata: metadata
    )
  end

  def self.membership_created(invitation:, user:, membership:, actor_membership: nil)
    record(
      "membership.created_via_invitation",
      invitation: invitation,
      actor_membership: actor_membership,
      subject: membership,
      metadata: {
        "user_id" => user.id,
        "membership_id" => membership.id,
        "role_key" => membership.role_key
      }
    )
  end

  def self.record(event_type, invitation:, actor_membership: nil, subject: nil, metadata: {})
    AuditEvent.record!(
      event_type: event_type,
      organization: invitation.organization,
      actor_membership: actor_membership,
      subject: subject || invitation,
      metadata: metadata.merge(
        "invitation_id" => invitation.id,
        "organization_id" => invitation.organization_id,
        "invited_email" => invitation.email
      )
    )
  end
end
