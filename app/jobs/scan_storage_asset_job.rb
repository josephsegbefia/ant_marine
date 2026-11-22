# frozen_string_literal: true

class ScanStorageAssetJob < ApplicationJob
  queue_as :default

  self.log_arguments = false

  retry_on Timeout::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(storage_asset_id)
    asset = Storage::Asset.find_by(id: storage_asset_id)
    return unless asset
    return if asset.scan_status.in?(%w[available rejected])

    asset.mark_scanning!

    blob = asset.active_storage_blob
    return asset.mark_rejected!(reason: "missing_blob") unless blob

    result = nil
    begin
      blob.open do |file|
        result = Storage::MalwareScanner.scan(file)
      end
    rescue ActiveStorage::IntegrityError, ActiveStorage::FileNotFoundError
      asset.mark_rejected!(reason: "blob_unreadable")
      Storage::Audit.scan_rejected(asset: asset)
      return
    end

    unless result
      asset.mark_rejected!(reason: "scan_no_result")
      Storage::Audit.scan_rejected(asset: asset)
      return
    end

    case result.status
    when :clean
      asset.mark_available!(scan_result: result.detail)
      Storage::Audit.scan_passed(asset: asset)
    when :rejected
      asset.mark_rejected!(reason: result.detail, scan_result: result.detail)
      Storage::Audit.scan_rejected(asset: asset)
    else
      asset.mark_rejected!(reason: "scan_failed", scan_result: result.detail)
      Storage::Audit.scan_rejected(asset: asset)
    end
  end
end
