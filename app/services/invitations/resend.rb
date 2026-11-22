# frozen_string_literal: true

module Invitations
  class Resend
    def self.call(inviter_membership:, invitation:)
      new(inviter_membership: inviter_membership).call(invitation: invitation)
    end

    def initialize(inviter_membership:)
      @inviter_membership = inviter_membership
      @policy = Policy.new(inviter_membership: inviter_membership)
    end

    def call(invitation:)
      @policy.manage_allowed!(invitation: invitation)
      raise Error, "Only pending invitations can be resent." unless invitation.status == "pending"

      result = Issue.call(
        inviter_membership: @inviter_membership,
        organization: invitation.organization,
        email: invitation.email,
        role_key: invitation.role_key
      )

      InvitationAudit.reissued(invitation: result.invitation, actor_membership: @inviter_membership)
      result
    rescue Policy::Denied => e
      InvitationAudit.denied(
        actor_membership: @inviter_membership,
        organization: invitation.organization,
        metadata: { "reason" => "resend_denied", "invitation_id" => invitation.id }
      )
      raise e
    end

    class Error < StandardError; end
  end
end
