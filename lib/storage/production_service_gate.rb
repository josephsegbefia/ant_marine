# frozen_string_literal: true

module Storage
  module ProductionServiceGate
    class Blocked < StandardError; end

    ENCRYPTED_SERVICES = %i[local_encrypted encrypted_s3].freeze
    PLAIN_S3_SERVICE = :private_s3

    module_function

    def verify!(service_name:)
      return unless Rails.env.production?

      name = service_name.to_sym
      return if ENCRYPTED_SERVICES.include?(name)

      if name == PLAIN_S3_SERVICE
        raise Blocked,
              "private_s3 stores ciphertext only with an encrypted adapter; plain S3 is blocked for confidential storage (set Active Storage to local_encrypted or ship EncryptedS3Service)"
      end

      raise Blocked, "Active Storage service #{name.inspect} is not approved for production confidential storage"
    end
  end
end
