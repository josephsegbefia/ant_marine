# frozen_string_literal: true

module Storage
  class ProofUpload
    Result = Data.define(:asset)

    class Error < StandardError; end

    def self.call(membership:, organization:, filename:, io:, classification: "standard")
      new(membership: membership).call(organization: organization, filename: filename, io: io, classification: classification)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(organization:, filename:, io:, classification:)
      raise Error, "organization mismatch" unless @membership.organization_id == organization.id
      raise Error, "invalid classification" unless Storage::Asset::CLASSIFICATIONS.include?(classification)

      validated = ContentValidator.call(filename: filename, io: io)
      storage_key = SecureRandom.uuid
      checksum_sha256 = Digest::SHA256.hexdigest(validated[:bytes])

      asset = nil
      ActiveRecord::Base.transaction do
        asset = Storage::Asset.create!(
          organization: organization,
          uploaded_by_membership: @membership,
          scan_status: "pending_upload",
          classification: classification,
          filename: File.basename(filename),
          content_type: validated[:content_type],
          byte_size: validated[:byte_size],
          checksum_sha256: checksum_sha256,
          storage_key: storage_key,
          encryption_key_version: KeyMaterial.current_version
        )

        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(validated[:bytes]),
          filename: asset.filename,
          content_type: asset.content_type,
          identify: false,
          key: storage_key
        )
        asset.update!(active_storage_blob_id: blob.id)
      end

      ScanStorageAssetJob.perform_later(asset.id)
      Audit.proof_uploaded(asset: asset, actor_membership: @membership)

      Result.new(asset: asset)
    end
  end
end
