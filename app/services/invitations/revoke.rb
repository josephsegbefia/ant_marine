# frozen_string_literal: true

module Invitations
  class Revoke
    def self.call(inviter_membership:, invitation:)
      new(inviter_membership: inviter_membership).call(invitation: invitation)
    end

    def initialize(inviter_membership:)
      @inviter_membership = inviter_membership
      @policy = Policy.new(inviter_membership: inviter_membership)
    end

    def call(invitation:)
      @policy.manage_allowed!(invitation: invitation)
      return invitation unless invitation.status == "pending"

      invitation.revoke!
      InvitationAudit.revoked(invitation: invitation, actor_membership: @inviter_membership)
      invitation
    rescue Policy::Denied => e
      InvitationAudit.denied(
        actor_membership: @inviter_membership,
        organization: invitation.organization,
        metadata: { "reason" => "revoke_denied", "invitation_id" => invitation.id }
      )
      raise e
    end
  end
end
