# frozen_string_literal: true

module Storage
  class SecureDownload
    Payload = Data.define(:asset, :plaintext, :content_type, :filename)

    class Error < StandardError; end

    def self.call(asset:)
      raise Error, "asset not available" unless asset.downloadable?
      raise Error, "blob missing" unless asset.active_storage_blob
      raise Error, "scan digest mismatch" unless asset.scanned_checksum_sha256.present? &&
        ActiveSupport::SecurityUtils.secure_compare(asset.scanned_checksum_sha256, asset.checksum_sha256)

      plaintext = begin
        asset.active_storage_blob.download
      rescue ActiveStorage::IntegrityError
        raise Error, "decryption failed"
      end
      raise Error, "decryption failed" if plaintext.blank?

      expected = Digest::SHA256.hexdigest(plaintext)
      raise Error, "checksum mismatch" unless ActiveSupport::SecurityUtils.secure_compare(expected, asset.checksum_sha256)
      raise Error, "scan digest mismatch" unless ActiveSupport::SecurityUtils.secure_compare(expected, asset.scanned_checksum_sha256)

      Payload.new(
        asset: asset,
        plaintext: plaintext,
        content_type: asset.content_type,
        filename: asset.filename
      )
    end
  end
end
