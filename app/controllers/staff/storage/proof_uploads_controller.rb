# frozen_string_literal: true

module Staff
  module Storage
    class ProofUploadsController < Staff::BaseController
      def create
        organization = Current.membership.organization
        authorize organization, :create?, policy_class: ::Storage::ProofPolicy

        file = upload_params[:file]
        filename = upload_params[:filename].presence || file.original_filename
        result = ::Storage::ProofUpload.call(
          membership: Current.membership,
          organization: organization,
          filename: filename,
          io: file.tempfile,
          classification: upload_params[:classification].presence || "standard"
        )

        render json: { storage_asset_id: result.asset.id, scan_status: result.asset.scan_status }, status: :created
      rescue ::Storage::ProofUpload::Error, ::Storage::ContentValidator::Error => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

        def upload_params
          params.require(:proof_upload).permit(:file, :filename, :classification)
        end
    end
  end
end
