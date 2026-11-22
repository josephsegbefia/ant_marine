# frozen_string_literal: true

module Notifications
  # Authenticated encryption for the invitation raw token in Solid Queue job arguments.
  # The ciphertext is opaque without secret_key_base; tampering and expiry are rejected.
  module InvitationTokenSeal
    PURPOSE = "invitation_delivery"

    def self.seal(raw_token, expires_at:)
      encryptor.encrypt_and_sign({ "token" => raw_token }, expires_at: expires_at)
    end

    def self.open(sealed)
      payload = encryptor.decrypt_and_verify(sealed)
      return if payload.blank?

      payload["token"] || payload[:token]
    rescue ActiveSupport::MessageEncryptor::InvalidMessage,
           ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def self.encryptor
      @encryptor ||= begin
        key = Rails.application.key_generator.generate_key(
          "message_encryptor/#{PURPOSE}",
          ActiveSupport::MessageEncryptor.key_len
        )
        ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
      end
    end
  end
end
