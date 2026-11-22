# frozen_string_literal: true

module Invitations
  module Token
    module_function

    def generate
      raw = SecureRandom.urlsafe_base64(32)
      [ raw, digest(raw) ]
    end

    def digest(raw_token)
      Digest::SHA256.hexdigest(raw_token.to_s)
    end

    def matches?(raw_token, digest)
      return false if raw_token.blank? || digest.blank?

      ActiveSupport::SecurityUtils.secure_compare(digest(raw_token), digest)
    end
  end
end
