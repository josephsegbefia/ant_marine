# frozen_string_literal: true

module Notifications
  # Signed, expiring envelope so the raw invitation token is not stored in plaintext
  # in Solid Queue job arguments. Anyone with secret_key_base can still open it.
  module InvitationTokenSeal
    PURPOSE = "invitation_delivery"

    def self.seal(raw_token, expires_at:)
      verifier.generate({ "token" => raw_token }, expires_at: expires_at)
    end

    def self.open(sealed)
      payload = verifier.verified(sealed)
      return if payload.blank?

      payload["token"]
    end

    def self.verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
