# frozen_string_literal: true

require "test_helper"
require "net/http"

class MinioEncryptedStoragePocTest < ActiveSupport::TestCase
  def self.minio_available?
    ENV["MINIO_POC_ENABLED"] == "1" && minio_reachable?
  end

  def self.minio_reachable?
    uri = URI(ENV.fetch("MINIO_POC_ENDPOINT", "http://127.0.0.1:9000"))
    Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 2) { |http| http.head("/") }
    true
  rescue StandardError
    false
  end

  setup do
    skip "MINIO_POC_ENABLED=1 with reachable MinIO required" unless self.class.minio_available?

    configurations = Rails.application.config.active_storage.service_configurations.deep_symbolize_keys
    @prior_service = ActiveStorage::Blob.service
    ActiveStorage::Blob.service = ActiveStorage::Service::Configurator.build(:encrypted_s3, configurations)
  end

  teardown do
    ActiveStorage::Blob.service = @prior_service if defined?(@prior_service)
  end

  test "encrypted upload stores ciphertext in MinIO and round-trips plaintext" do
    bytes = "MinIO encrypted PoC #{SecureRandom.hex(4)}"
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(bytes),
      filename: "poc.txt",
      content_type: "text/plain",
      identify: false,
      key: SecureRandom.uuid,
      service_name: ActiveStorage::Blob.service.name
    )

    raw_s3 = blob.service.instance_variable_get(:@s3).download(blob.key)
    assert_not_includes raw_s3, bytes
    assert_equal bytes, blob.download
    blob.purge
  end

  test "tampered object in MinIO fails decryption" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("tamper probe"),
      filename: "tamper.txt",
      content_type: "text/plain",
      identify: false,
      key: SecureRandom.uuid,
      service_name: ActiveStorage::Blob.service.name
    )
    inner = blob.service.instance_variable_get(:@s3)
    ciphertext = inner.download(blob.key)
    tampered = ciphertext.sub(/A/, "B")
    inner.upload(blob.key, StringIO.new(tampered), checksum: OpenSSL::Digest::MD5.base64digest(tampered))

    assert_raises(ActiveStorage::IntegrityError) { blob.download }
  ensure
    blob&.purge
  end
end
