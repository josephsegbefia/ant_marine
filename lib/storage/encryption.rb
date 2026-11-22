# frozen_string_literal: true

module Storage
  module Encryption
    HEADER = "AMST"
    SEPARATOR = "."

    module_function

    def encrypt(plaintext, key_version: KeyMaterial.current_version)
      packed = KeyMaterial.encryptor(key_version).encrypt_and_sign(
        plaintext,
        purpose: :storage_blob
      )
      "#{HEADER}#{key_version}#{SEPARATOR}#{packed}"
    end

    def decrypt(ciphertext)
      header, version, packed = parse_envelope!(ciphertext)
      version = version.to_i
      KeyMaterial.encryptor(version).decrypt_and_verify(packed, purpose: :storage_blob)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError
      nil
    end

    def parse_envelope!(ciphertext)
      match = ciphertext.to_s.match(/\A#{HEADER}(\d+)#{Regexp.escape(SEPARATOR)}(.+)\z/m)
      raise ArgumentError, "invalid storage envelope" if match.nil?

      [ HEADER, match[1], match[2] ]
    end
    private_class_method :parse_envelope!
  end
end
