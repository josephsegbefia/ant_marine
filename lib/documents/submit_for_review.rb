# frozen_string_literal: true

module Documents
  class SubmitForReview
    Result = Data.define(:document, :version)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, document:, version: nil)
      new(membership: membership).call(document: document, version: version)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(document:, version:)
      raise Denied, "Only staff can submit documents for review." unless @membership.staff_domain?
      raise Denied, "You are not allowed to manage this document." unless Documents::Access.can_upload?(@membership, document.project)

      version ||= document.current_version
      raise InvalidState, "Upload a file before submitting for review." unless version
      raise InvalidState, "Security checks must finish successfully before review." unless version.downloadable?
      raise InvalidState, "This version does not belong to the document." unless version.document_id == document.id
      raise InvalidState, "This document is already under review or approved." unless document.workflow_status.in?(%w[working_draft changes_requested])

      Document.transaction do
        locked = Document.lock.find(document.id)
        locked.update!(workflow_status: "submitted")
        if locked.upload_request&.status.in?(%w[submitted changes_required])
          locked.upload_request.update!(status: "under_review")
        end
        audit = Documents::Audit.submitted_for_review(document: locked, version: version, actor_membership: @membership)
        Notifications::StaffPublisher.document_review_required(document: locked, audit_event: audit, actor: @membership)
        Result.new(document: locked, version: version)
      end
    end
  end
end
