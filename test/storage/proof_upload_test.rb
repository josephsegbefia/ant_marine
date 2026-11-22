# frozen_string_literal: true

require "test_helper"

class StorageProofUploadTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @membership = memberships(:super_admin_membership)
  end

  test "valid file is accepted into quarantine then becomes available" do
    asset = upload_storage_proof!(membership: @membership, bytes: "Hello PoC")

    assert_equal "available", asset.scan_status
  end

  test "unsupported type is rejected" do
    binary = "\x7FELF\x00\x01\x02".b
    assert_raises Storage::ContentValidator::TypeNotAllowed do
      Storage::ProofUpload.call(
        membership: @membership,
        organization: @membership.organization,
        filename: "malware.bin",
        io: StringIO.new(binary)
      )
    end
  end

  test "oversized file is rejected" do
    huge = "a" * (ENV.fetch("STORAGE_MAX_UPLOAD_BYTES").to_i + 1)
    assert_raises Storage::ContentValidator::TooLarge do
      Storage::ProofUpload.call(
        membership: @membership,
        organization: @membership.organization,
        filename: "big.txt",
        io: StringIO.new(huge)
      )
    end
  end

  test "empty file is rejected" do
    assert_raises ActiveRecord::RecordInvalid do
      Storage::ProofUpload.call(
        membership: @membership,
        organization: @membership.organization,
        filename: "empty.txt",
        io: StringIO.new("")
      )
    end
  end

  test "path traversal filename is rejected" do
    assert_raises Storage::ContentValidator::FilenameInvalid do
      Storage::ProofUpload.call(
        membership: @membership,
        organization: @membership.organization,
        filename: "../etc/passwd",
        io: StringIO.new("Hello")
      )
    end
  end

  test "eicar is rejected by scan" do
    asset = nil
    perform_enqueued_jobs only: ScanStorageAssetJob do
      asset = Storage::ProofUpload.call(
        membership: @membership,
        organization: @membership.organization,
        filename: "eicar.txt",
        io: StringIO.new(Storage::MalwareScanner::EICAR_TEST_STRING)
      ).asset
    end

    assert_equal "rejected", asset.reload.scan_status
  end
end
