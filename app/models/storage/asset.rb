# frozen_string_literal: true

module Storage
  class Asset < ApplicationRecord
    self.table_name = "storage_assets"

    SCAN_STATUSES = %w[pending_upload scanning available rejected].freeze
    CLASSIFICATIONS = %w[standard confidential].freeze
    IDENTITY_ATTRS = %w[
      checksum_sha256 storage_key byte_size content_type filename
      active_storage_blob_id organization_id classification encryption_key_version
    ].freeze

    belongs_to :organization
    belongs_to :uploaded_by_membership, class_name: "Membership"
    belongs_to :active_storage_blob, class_name: "ActiveStorage::Blob", optional: true

    validates :scan_status, inclusion: { in: SCAN_STATUSES }
    validates :classification, inclusion: { in: CLASSIFICATIONS }
    validates :filename, :content_type, :checksum_sha256, :storage_key, presence: true
    validates :byte_size, numericality: { greater_than: 0, only_integer: true }
    validates :encryption_key_version, numericality: { greater_than: 0, only_integer: true }
    validate :identity_immutable_after_verification, on: :update
    validate :available_requires_matching_scanned_checksum

    scope :for_organization, ->(organization) { where(organization_id: organization.id) }

    def available?
      scan_status == "available" &&
        scanned_checksum_sha256.present? &&
        ActiveSupport::SecurityUtils.secure_compare(scanned_checksum_sha256, checksum_sha256)
    end

    def confidential?
      classification == "confidential"
    end

    def downloadable?
      available?
    end

    def verified?
      available?
    end

    def mark_scanning!
      updated = self.class.where(id: id, scan_status: %w[pending_upload scanning])
                    .update_all(scan_status: "scanning", updated_at: Time.current)
      raise ActiveRecord::RecordNotFound, "asset not scannable" if updated.zero?

      reload
    end

    def mark_available!(scan_result:, scanner_adapter: nil)
      update!(
        scan_status: "available",
        scan_result: scan_result,
        scanner_adapter: scanner_adapter.presence || scan_result,
        scanned_checksum_sha256: checksum_sha256,
        scanned_at: Time.current,
        rejected_reason: nil
      )
    end

    def mark_rejected!(reason:, scan_result: nil, scanner_adapter: nil)
      update!(
        scan_status: "rejected",
        rejected_reason: reason,
        scan_result: scan_result,
        scanner_adapter: scanner_adapter.presence || scan_result,
        scanned_at: Time.current
      )
    end

    private

      def identity_immutable_after_verification
        return unless scan_status_was.in?(%w[available rejected])

        IDENTITY_ATTRS.each do |attr|
          next unless will_save_change_to_attribute?(attr)

          errors.add(attr, "cannot change after security verification")
        end
      end

      def available_requires_matching_scanned_checksum
        return unless scan_status == "available"
        return if scanned_checksum_sha256.present? &&
          ActiveSupport::SecurityUtils.secure_compare(scanned_checksum_sha256, checksum_sha256)

        errors.add(:scanned_checksum_sha256, "must match content digest when available")
      end
  end
end
