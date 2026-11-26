# frozen_string_literal: true

module Billing
  module SecureDownload
    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    Result = Data.define(:bytes, :filename, :content_type, :checksum)

    module_function

    def call(membership:, invoice:)
      raise Denied, "You are not allowed to download this invoice." unless Billing::Access.can_download?(membership, invoice)
      raise InvalidState, "No issued PDF is available for this invoice." if invoice.storage_asset_id.blank?

      asset = invoice.storage_asset
      raise InvalidState, "Invoice PDF is not available." unless asset&.downloadable?
      if invoice.artifact_checksum_sha256.blank? ||
         !ActiveSupport::SecurityUtils.secure_compare(invoice.artifact_checksum_sha256, asset.checksum_sha256)
        raise InvalidState, "Invoice PDF integrity check failed."
      end

      storage = Storage::SecureDownload.call(asset: asset)
      digest = Digest::SHA256.hexdigest(storage.plaintext)
      unless ActiveSupport::SecurityUtils.secure_compare(digest, invoice.artifact_checksum_sha256)
        raise InvalidState, "Invoice PDF integrity check failed."
      end

      Billing::Audit.downloaded(invoice: invoice, actor_membership: membership)

      Result.new(
        bytes: storage.plaintext,
        filename: "#{invoice.reference_number}.pdf",
        content_type: "application/pdf",
        checksum: digest
      )
    end
  end
end
