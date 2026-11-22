# frozen_string_literal: true

module Notifications
  class Dispatch
    def self.invitation!(invitation:, raw_token:)
      MailDelivery.ensure_ready!
      Events.fetch(Events::INVITATION_ISSUED)
      DeliverInvitationEmailJob.perform_later(
        invitation.id,
        InvitationTokenSeal.seal(raw_token, expires_at: invitation.expires_at)
      )
    end

    def self.password_reset!(user:)
      MailDelivery.ensure_ready!
      Events.fetch(Events::PASSWORD_RESET_REQUESTED)
      PasswordsMailer.reset(user).deliver_later
    end
  end
end
