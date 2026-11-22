# frozen_string_literal: true

module Staff
  module Storage
    class ProofDownloadsController < Staff::BaseController
      def show
        asset = ::Storage::Asset.find(params[:id])
        authorize asset, :show?, policy_class: ::Storage::AssetPolicy

        payload = ::Storage::SecureDownload.call(asset: asset)
        ::Storage::Audit.download_allowed(asset: asset, actor_membership: Current.membership)

        response.headers["Cache-Control"] = "no-store"
        send_data payload.plaintext,
          filename: payload.filename,
          type: payload.content_type,
          disposition: "attachment"
      rescue ::Storage::SecureDownload::Error
        ::Storage::Audit.download_denied(asset: asset, actor_membership: Current.membership, reason: "not_available")
        head :not_found
      rescue Pundit::NotAuthorizedError
        ::Storage::Audit.download_denied(asset: asset, actor_membership: Current.membership, reason: "policy_denied")
        raise
      end
    end
  end
end
