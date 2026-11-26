# frozen_string_literal: true

module Documents
  class RevokeRelease
    Result = Data.define(:document, :release)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, release:, reason:)
      new(membership: membership).call(release: release, reason: reason)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(release:, reason:)
      raise Denied, "You are not allowed to revoke this release." unless Documents::Access.can_revoke_release?(@membership, release)
      raise InvalidState, "This release is already revoked." unless release.active?
      raise InvalidState, "Explain why client access should be withdrawn." if reason.to_s.strip.blank?

      Document.transaction do
        locked_release = DocumentRelease.lock.find(release.id)
        raise InvalidState, "This release is already revoked." unless locked_release.active?

        locked_release.update!(
          revoked_at: Time.current,
          revocation_reason: reason.to_s.strip
        )
        document = Document.lock.find(locked_release.document_id)
        document.update!(workflow_status: "approved") if document.workflow_status == "released"
        audit = Documents::Audit.release_revoked(
          document: document,
          release: locked_release,
          actor_membership: @membership
        )
        Notifications::StaffPublisher.document_release_revoked(document: document, audit_event: audit, actor: @membership)
        Result.new(document: document, release: locked_release)
      end
    end
  end
end
