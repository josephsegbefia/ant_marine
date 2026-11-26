# frozen_string_literal: true

require "test_helper"

class ScanStorageAssetJobH1Test < ActiveJob::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
  end

  test "scanner error ends with rejected asset not available" do
    asset = pending_asset
    error_result = Storage::MalwareScanner::Result.new(status: :error, detail: "job_h1_error", adapter: "test_error")

    with_malware_scan_result(error_result) do
      ScanStorageAssetJob.perform_now(asset.id)
    end

    asset.reload
    assert_equal "rejected", asset.scan_status
    assert_equal "test_error", asset.scanner_adapter
    assert_equal "scan_failed", asset.rejected_reason
    assert_not asset.available?
  end

  test "non allowlisted external command in test env fails closed to rejected" do
    asset = pending_asset
    original_command = ENV["STORAGE_SCAN_COMMAND"]
    ENV["STORAGE_SCAN_COMMAND"] = "cat"

    ScanStorageAssetJob.perform_now(asset.id)

    asset.reload
    assert_equal "rejected", asset.scan_status
    assert_equal "denied", asset.scanner_adapter
    assert_includes asset.scan_result.to_s, "scanner_command_not_allowlisted"
  ensure
    ENV["STORAGE_SCAN_COMMAND"] = original_command
  end

  private

    def pending_asset
      result = Documents::Upload.call(
        membership: @staff,
        project: @project,
        filename: "job-h1.txt",
        io: StringIO.new("job-h1-bytes"),
        title: "Job H1",
        category: "other"
      )
      asset = result.version.storage_asset
      assert_equal "pending_upload", asset.scan_status
      asset
    end
end
