# frozen_string_literal: true

module Storage
  module Audit
    module_function

    def proof_uploaded(asset:, actor_membership:)
      record("storage.proof_uploaded", asset:, actor_membership:, metadata: base_metadata(asset))
    end

    def scan_passed(asset:)
      record("storage.scan_passed", asset:, metadata: base_metadata(asset).merge("scan_result" => asset.scan_result))
    end

    def scan_rejected(asset:)
      record("storage.scan_rejected", asset:, metadata: base_metadata(asset).merge("rejected_reason" => asset.rejected_reason))
    end

    def download_allowed(asset:, actor_membership:)
      record("storage.download_allowed", asset:, actor_membership:, metadata: base_metadata(asset))
    end

    def download_denied(asset: nil, actor_membership:, reason:)
      record(
        "storage.download_denied",
        asset: asset,
        actor_membership: actor_membership,
        metadata: { "reason" => reason }.merge(asset ? base_metadata(asset) : {})
      )
    end

    def recovery_verified(asset:)
      record("storage.recovery_verified", asset:, metadata: base_metadata(asset))
    end

    def record(event_type, asset:, actor_membership: nil, metadata: {})
      AuditEvent.record!(
        event_type: event_type,
        organization: asset&.organization,
        actor_membership: actor_membership,
        subject: asset,
        metadata: metadata
      )
    end

    def base_metadata(asset)
      {
        "storage_asset_id" => asset.id,
        "organization_id" => asset.organization_id,
        "scan_status" => asset.scan_status,
        "byte_size" => asset.byte_size,
        "checksum_sha256" => asset.checksum_sha256,
        "classification" => asset.classification
      }
    end
  end
end
