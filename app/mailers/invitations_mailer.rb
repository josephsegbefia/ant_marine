# frozen_string_literal: true

class InvitationsMailer < ApplicationMailer
  def invite(invitation, raw_token)
    @invitation = invitation
    @organization = invitation.organization
    @accept_url = invitation_url(token: raw_token)
    @expires_at = invitation.expires_at

    mail(
      to: invitation.email,
      subject: "You are invited to join #{@organization.name} on ANT Marine"
    )
  end
end
