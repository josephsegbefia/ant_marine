# frozen_string_literal: true

module Storage
  module KeyMaterial
    class MissingKey < StandardError
      def initialize
        super("STORAGE_ENCRYPTION_KEY is not configured")
      end
    end

    module_function

    def current_version
      ENV.fetch("STORAGE_ENCRYPTION_KEY_VERSION", "1").to_i
    end

    def master_secret
      secret = ENV["STORAGE_ENCRYPTION_KEY"].presence
      return secret if secret.present?
      raise MissingKey unless Rails.env.test?

      "test-only-storage-encryption-secret"
    end

    def encryptor(version = current_version)
      key = Rails.application.key_generator.generate_key(
        "storage_encryption/v#{version}/#{master_secret}",
        ActiveSupport::MessageEncryptor.key_len
      )
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: Marshal)
    end
  end
end
