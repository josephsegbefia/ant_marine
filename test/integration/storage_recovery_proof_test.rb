# frozen_string_literal: true

require "test_helper"

class StorageRecoveryProofTest < ActiveSupport::TestCase
  test "restored blob bytes decrypt to original checksum" do
    membership = memberships(:super_admin_membership)
    bytes = "Recovery proof synthetic payload"
    asset = upload_storage_proof!(membership: membership, bytes: bytes)
    blob = asset.active_storage_blob
    source_path = blob.service.send(:path_for, blob.key)

    recovery_dir = Rails.root.join("tmp/storage_recovery_proof")
    FileUtils.mkdir_p(recovery_dir)
    recovery_path = recovery_dir.join(File.basename(source_path))
    FileUtils.cp(source_path, recovery_path)

    snapshot = asset.attributes.except("id", "created_at", "updated_at")
    blob_id = blob.id

    ActiveRecord::Base.transaction do
      asset.delete
      blob.purge
    end

    encrypted = File.binread(recovery_path)
    restored_blob = ActiveStorage::Blob.create!(
      key: snapshot["storage_key"],
      filename: snapshot["filename"],
      content_type: snapshot["content_type"],
      byte_size: encrypted.bytesize,
      checksum: OpenSSL::Digest::MD5.base64digest(encrypted),
      service_name: ActiveStorage::Blob.service.name
    )
    FileUtils.cp(recovery_path, restored_blob.service.send(:path_for, restored_blob.key))

    restored_asset = Storage::Asset.create!(snapshot.merge("active_storage_blob_id" => restored_blob.id))

    payload = Storage::SecureDownload.call(asset: restored_asset)
    assert_equal bytes, payload.plaintext
    assert_equal Digest::SHA256.hexdigest(bytes), restored_asset.checksum_sha256
    Storage::Audit.recovery_verified(asset: restored_asset)
    assert AuditEvent.exists?(event_type: "storage.recovery_verified")
  ensure
    FileUtils.rm_rf(Rails.root.join("tmp/storage_recovery_proof"))
  end
end
