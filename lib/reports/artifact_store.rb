# frozen_string_literal: true

module Reports
  module ArtifactStore
    class Error < StandardError; end

    module_function

    def persist_pdf!(membership:, organization:, pdf_bytes:, filename:)
      validated = Storage::ContentValidator.call(filename: filename, io: StringIO.new(pdf_bytes))
      checksum = Digest::SHA256.hexdigest(validated[:bytes])
      storage_key = SecureRandom.uuid

      asset = nil
      ActiveRecord::Base.transaction do
        asset = Storage::Asset.create!(
          organization: organization,
          uploaded_by_membership: membership,
          scan_status: "pending_upload",
          classification: "standard",
          filename: File.basename(filename),
          content_type: validated[:content_type],
          byte_size: validated[:byte_size],
          checksum_sha256: checksum,
          storage_key: storage_key,
          encryption_key_version: Storage::KeyMaterial.current_version
        )

        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(validated[:bytes]),
          filename: asset.filename,
          content_type: asset.content_type,
          identify: false,
          key: storage_key
        )
        asset.update!(active_storage_blob_id: blob.id)
        # Trusted application-generated PDF path only — never for ordinary user uploads.
        asset.mark_available!(
          scan_result: "application_generated_report_pdf",
          scanner_adapter: "application_generated"
        )
      end

      asset
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.record.errors.full_messages.to_sentence
    end
  end
end
