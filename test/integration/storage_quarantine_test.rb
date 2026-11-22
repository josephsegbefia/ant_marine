# frozen_string_literal: true

require "test_helper"

class StorageQuarantineTest < ActionDispatch::IntegrationTest
  setup do
    @membership = memberships(:super_admin_membership)
  end

  test "pending asset cannot download" do
    asset = Storage::ProofUpload.call(
      membership: @membership,
      organization: @membership.organization,
      filename: "pending.txt",
      io: StringIO.new("pending quarantine")
    ).asset
    assert_equal "pending_upload", asset.reload.scan_status
    assert_enqueued_jobs 1, only: ScanStorageAssetJob

    sign_in_as users(:super_admin), membership: @membership
    get staff_storage_proof_download_path(asset)

    assert_redirected_to root_path
  end

  test "rejected asset cannot download" do
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

    sign_in_as users(:super_admin), membership: @membership
    get staff_storage_proof_download_path(asset)

    assert_redirected_to root_path
  end

  test "scanning asset cannot download" do
    asset = Storage::ProofUpload.call(
      membership: @membership,
      organization: @membership.organization,
      filename: "scanning.txt",
      io: StringIO.new("still scanning")
    ).asset
    asset.update!(scan_status: "scanning")

    sign_in_as users(:super_admin), membership: @membership
    get staff_storage_proof_download_path(asset)

    assert_redirected_to root_path
  end
end
