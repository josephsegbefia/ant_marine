# frozen_string_literal: true

module Reports
  class SecureDownload
    Payload = Data.define(:version, :plaintext, :content_type, :filename)

    class Error < StandardError; end
    class Denied < Error; end

    def self.call(membership:, version:)
      new(membership: membership).call(version: version)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(version:)
      report = version.report
      unless authorized?(membership: @membership, report: report, version: version)
        Reports::Audit.download_denied(report: report, version: version, actor_membership: @membership)
        raise Denied, "You are not allowed to download this report."
      end

      asset = version.storage_asset
      raise Error, "This report version has no stored PDF." unless asset&.downloadable?
      if version.artifact_checksum_sha256.blank? ||
         !ActiveSupport::SecurityUtils.secure_compare(version.artifact_checksum_sha256, asset.checksum_sha256)
        raise Error, "The approved report artifact failed integrity verification."
      end

      storage = Storage::SecureDownload.call(asset: asset)
      if Digest::SHA256.hexdigest(storage.plaintext) != version.artifact_checksum_sha256
        raise Error, "The approved report artifact failed integrity verification."
      end

      Reports::Audit.download_allowed(report: report, version: version, actor_membership: @membership)

      Payload.new(
        version: version,
        plaintext: storage.plaintext,
        content_type: "application/pdf",
        filename: "#{report.reference_number}-v#{version.version_number}.pdf"
      )
    end

    private

      def authorized?(membership:, report:, version:)
        if membership.staff_domain?
          Reports::Access.can_view_metadata?(membership, report) &&
            version.approved? &&
            report.project.operating_organization_id == membership.organization_id
        elsif membership.client_domain?
          release = report.report_releases.active.find_by(client_organization_id: membership.organization_id)
          release.present? && release.report_version_id == version.id
        else
          false
        end
      end
  end
end
