# frozen_string_literal: true

require "test_helper"

class ScanStorageAssetJobTest < ActiveJob::TestCase
  test "job completes scan after upload" do
  asset = nil
    perform_enqueued_jobs only: ScanStorageAssetJob do
      asset = Storage::ProofUpload.call(
        membership: memberships(:super_admin_membership),
        organization: organizations(:ant_marine),
        filename: "poc.txt",
        io: StringIO.new("Hello scan job"),
        classification: "standard"
      ).asset
    end

    assert_equal "available", asset.reload.scan_status
    assert ScanStorageAssetJob.log_arguments != true
  end

  test "repeated scan does not downgrade available asset" do
    asset = upload_storage_proof!(membership: memberships(:super_admin_membership), bytes: "repeat")
    assert_no_changes -> { asset.reload.scan_status } do
      ScanStorageAssetJob.perform_now(asset.id)
    end
  end
end
