# frozen_string_literal: true

module Documents
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
      unless Documents::Access.can_download_version?(@membership, version)
        Documents::Audit.download_denied(version: version, actor_membership: @membership)
        raise Denied, "You are not allowed to download this file."
      end

      storage = Storage::SecureDownload.call(asset: version.storage_asset)
      Documents::Audit.download_allowed(version: version, actor_membership: @membership)

      Payload.new(
        version: version,
        plaintext: storage.plaintext,
        content_type: storage.content_type,
        filename: version.filename.presence || storage.filename
      )
    end
  end
end
