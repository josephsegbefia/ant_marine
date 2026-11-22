# frozen_string_literal: true

require "net/smtp"

class DeliverInvitationEmailJob < ApplicationJob
  queue_as :mail

  # Failed-job rows and enqueue logs must not print the sealed token.
  self.log_arguments = false

  retry_on Net::SMTPServerBusy, Net::SMTPUnknownError, wait: :polynomially_longer, attempts: 5
  discard_on Net::SMTPFatalError, Net::SMTPSyntaxError

  def perform(invitation_id, sealed_token)
    Notifications::MailDelivery.ensure_ready!

    invitation = Invitation.find_by(id: invitation_id)
    return unless invitation&.usable?

    raw_token = Notifications::InvitationTokenSeal.open(sealed_token)
    return if raw_token.blank?

    InvitationsMailer.invite(invitation, raw_token).deliver_now
  end
end
