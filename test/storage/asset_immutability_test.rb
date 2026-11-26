# frozen_string_literal: true

require "test_helper"

class Storage::AssetImmutabilityTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
  end

  test "after scan available sql update of checksum_sha256 raises statement invalid" do
    asset = scanned_available_asset!

    ActiveRecord::Base.connection.transaction(requires_new: true) do
      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.connection.execute(
          "UPDATE storage_assets SET checksum_sha256 = 'tampered' WHERE id = #{asset.id}"
        )
      end
      raise ActiveRecord::Rollback
    end
  end

  test "mark_available without matching scanned checksum fails validation" do
    asset = Storage::Asset.find(upload_pending_asset!.id)
    asset.update_columns(scan_status: "scanning")
    asset.assign_attributes(
      scan_status: "available",
      scan_result: "forced",
      scanned_checksum_sha256: "deadbeef",
      scanned_at: Time.current
    )
    assert_not asset.valid?
    assert asset.errors[:scanned_checksum_sha256].any?
  end

  test "available asset rejects tampered scanned checksum at database" do
    asset = scanned_available_asset!

    assert_raises(ActiveRecord::StatementInvalid) do
      asset.update_columns(scanned_checksum_sha256: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    end
  end

  test "available and downloadable false when scanned digest differs from content digest" do
    asset = scanned_available_asset!
    mismatched = asset.dup
    mismatched.id = asset.id
    mismatched.scanned_checksum_sha256 = "0" * 64

    assert_not mismatched.available?
    assert_not mismatched.downloadable?
    assert asset.available?
  end

  test "rejected asset cannot be marked available via sql" do
    asset = rejected_asset!

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "UPDATE storage_assets SET scan_status = 'available', scanned_checksum_sha256 = checksum_sha256 WHERE id = #{asset.id}"
      )
    end
  end

  private

    def upload_pending_asset!
      result = Documents::Upload.call(
        membership: @staff,
        project: @project,
        filename: "immutable.txt",
        io: StringIO.new("immutable-bytes"),
        title: "Immutability probe",
        category: "other"
      )
      result.version.storage_asset
    end

    def scanned_available_asset!
      asset = upload_pending_asset!
      perform_enqueued_jobs only: ScanStorageAssetJob
      asset.reload
      assert_equal "available", asset.scan_status
      asset
    end

    def rejected_asset!
      asset = upload_pending_asset!
      with_malware_scan_result(
        Storage::MalwareScanner::Result.new(status: :error, detail: "forced_reject", adapter: "test")
      ) do
        perform_enqueued_jobs only: ScanStorageAssetJob
      end
      asset.reload
      assert_equal "rejected", asset.scan_status
      asset
    end
end
