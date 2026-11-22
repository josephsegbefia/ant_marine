# frozen_string_literal: true

class InvitationsMailerPreview < ActionMailer::Preview
  def invite
    invitation = Invitation.pending.last || Invitation.first
    InvitationsMailer.invite(invitation, "preview-token-example")
  end
end
