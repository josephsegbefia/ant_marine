# frozen_string_literal: true

module Storage
  class Asset < ApplicationRecord
    self.table_name = "storage_assets"

    SCAN_STATUSES = %w[pending_upload scanning available rejected].freeze
    CLASSIFICATIONS = %w[standard confidential].freeze

    belongs_to :organization
    belongs_to :uploaded_by_membership, class_name: "Membership"
    belongs_to :active_storage_blob, class_name: "ActiveStorage::Blob", optional: true

    validates :scan_status, inclusion: { in: SCAN_STATUSES }
    validates :classification, inclusion: { in: CLASSIFICATIONS }
    validates :filename, :content_type, :checksum_sha256, :storage_key, presence: true
    validates :byte_size, numericality: { greater_than: 0, only_integer: true }
    validates :encryption_key_version, numericality: { greater_than: 0, only_integer: true }

    scope :for_organization, ->(organization) { where(organization_id: organization.id) }

    def available?
      scan_status == "available"
    end

    def confidential?
      classification == "confidential"
    end

    def downloadable?
      available?
    end

    def mark_scanning!
      update!(scan_status: "scanning")
    end

    def mark_available!(scan_result:)
      update!(scan_status: "available", scan_result: scan_result, scanned_at: Time.current, rejected_reason: nil)
    end

    def mark_rejected!(reason:, scan_result: nil)
      update!(
        scan_status: "rejected",
        rejected_reason: reason,
        scan_result: scan_result,
        scanned_at: Time.current
      )
    end
  end
end
