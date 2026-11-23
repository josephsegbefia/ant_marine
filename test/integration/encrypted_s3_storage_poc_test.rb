# frozen_string_literal: true

require "test_helper"
require "net/http"

class EncryptedS3StoragePocTest < ActiveSupport::TestCase
  def self.s3_poc_enabled?
    ENV["S3_POC_ENABLED"] == "1" || ENV["MINIO_POC_ENABLED"] == "1"
  end

  def self.s3_poc_endpoint
    ENV.fetch("S3_POC_ENDPOINT", ENV.fetch("MINIO_POC_ENDPOINT", "http://127.0.0.1:8333"))
  end

  def self.s3_reachable?
    require "aws-sdk-s3"
    uri = URI(s3_poc_endpoint)
    client = Aws::S3::Client.new(
      endpoint: s3_poc_endpoint,
      access_key_id: ENV.fetch("S3_POC_ACCESS_KEY", ENV.fetch("MINIO_POC_ACCESS_KEY", "ant_marine_s3_poc")),
      secret_access_key: ENV.fetch("S3_POC_SECRET_KEY", ENV.fetch("MINIO_POC_SECRET_KEY", "seaweedfs-poc-local-only")),
      region: ENV.fetch("S3_POC_REGION", "us-east-1"),
      force_path_style: true,
      http_open_timeout: 2,
      http_read_timeout: 2
    )
    client.list_buckets
    true
  rescue StandardError
    false
  end

  def self.s3_available?
    s3_poc_enabled? && s3_reachable?
  end

  setup do
    skip "S3_POC_ENABLED=1 with reachable S3-compatible endpoint required" unless self.class.s3_available?

    raw = YAML.safe_load(ERB.new(File.read(Rails.root.join("config/storage.yml"))).result, aliases: true)
    configurations = raw.deep_symbolize_keys
    @prior_service = ActiveStorage::Blob.service
    ActiveStorage::Blob.service = ActiveStorage::Service::Configurator.build(:encrypted_s3, configurations)
  end

  teardown do
    ActiveStorage::Blob.service = @prior_service if defined?(@prior_service)
  end

  test "encrypted upload stores ciphertext in S3 and round-trips plaintext with checksum" do
    bytes = "Encrypted S3 PoC #{SecureRandom.hex(4)}"
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
    assert_equal blob.checksum, OpenSSL::Digest::MD5.base64digest(bytes)
    blob.purge
  end

  test "tampered object in S3 fails decryption" do
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

  test "wrong decryption key rejects payload" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("wrong key probe"),
      filename: "key.txt",
      content_type: "text/plain",
      identify: false,
      key: SecureRandom.uuid,
      service_name: ActiveStorage::Blob.service.name
    )
    original = ENV["STORAGE_ENCRYPTION_KEY"]
    ENV["STORAGE_ENCRYPTION_KEY"] = "different-secret-material-for-wrong-key-test"
    assert_raises(ActiveStorage::IntegrityError) { blob.download }
  ensure
    ENV["STORAGE_ENCRYPTION_KEY"] = original
    blob&.purge
  end

  test "direct urls and active storage public routes stay disabled" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("gateway only"),
      filename: "gate.txt",
      content_type: "text/plain",
      identify: false,
      key: SecureRandom.uuid,
      service_name: ActiveStorage::Blob.service.name
    )
    assert_raises(NotImplementedError) { blob.service.url(blob.key) }
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/rails/active_storage/blobs/redirect/x", method: :get)
    end
  ensure
    blob&.purge
  end
end
