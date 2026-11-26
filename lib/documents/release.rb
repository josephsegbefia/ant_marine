# frozen_string_literal: true

module Documents
  class Release
    Result = Data.define(:document, :release)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.available?
      !Rails.env.production?
    end

    def self.call(membership:, document:, version:, confirmation: false)
      new(membership: membership).call(document: document, version: version, confirmation: confirmation)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(document:, version:, confirmation:)
      raise Denied, "Client document release is not available in production yet." unless self.class.available?
      raise Denied, "You are not allowed to release this document." unless Documents::Access.can_release?(@membership, document)
      raise Denied, "Simulated document release is not available in production." if Rails.env.production? && document.project.simulated?
      raise Error, "Confirm that this exact version should be shared with the client." unless ActiveModel::Type::Boolean.new.cast(confirmation)
      raise InvalidState, "This version does not belong to the document." unless version.document_id == document.id

      Document.transaction do
        locked = Document.lock.find(document.id)
        locked_version = DocumentVersion.lock.find(version.id)
        raise InvalidState, "This version does not belong to the document." unless locked_version.document_id == locked.id
        raise InvalidState, "Security checks must finish successfully before release." unless locked_version.downloadable?

        if locked.approval_required?
          approved = DocumentReview.where(document_version_id: locked_version.id, outcome: "approved").exists?
          raise InvalidState, "Approve this exact version before releasing it." unless approved
          raise InvalidState, "This document must be approved before release." unless locked.workflow_status.in?(%w[approved released])
        end

        active = locked.document_releases.active.lock.first
        raise InvalidState, "Revoke the current client release before sharing a different version." if active && active.document_version_id != locked_version.id
        return Result.new(document: locked, release: active) if active&.document_version_id == locked_version.id

        release_record = DocumentRelease.create!(
          document: locked,
          document_version: locked_version,
          client_organization: locked.client_organization,
          released_by_membership: @membership,
          released_at: Time.current,
          classification: locked.classification,
          release_kind: "client_share"
        )
        locked.update!(workflow_status: "released", visibility_intent: "for_client_release")
        if locked.upload_request.present? && locked.upload_request.status != "satisfied"
          locked.upload_request.update!(status: "satisfied", satisfied_document: locked)
        end
        Documents::Audit.released(document: locked, version: locked_version, release: release_record, actor_membership: @membership)
        Result.new(document: locked, release: release_record)
      end
    end
  end
end
