# frozen_string_literal: true

module Documents
  class Review
    Result = Data.define(:document, :review)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    OUTCOMES = %w[approved changes_requested].freeze

    def self.call(membership:, document:, version:, outcome:, comments: nil)
      new(membership: membership).call(
        document: document,
        version: version,
        outcome: outcome,
        comments: comments
      )
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(document:, version:, outcome:, comments:)
      raise Denied, "You are not allowed to review this document." unless Documents::Access.can_review?(@membership, document)
      raise InvalidState, "Choose approve or request changes." unless OUTCOMES.include?(outcome.to_s)
      raise InvalidState, "This version does not belong to the document." unless version.document_id == document.id
      raise InvalidState, "Submit the document for review first." unless document.workflow_status == "submitted"

      if document.approval_required? &&
         (version.uploaded_by_membership_id == @membership.id ||
          version.uploaded_by_membership&.user_id == @membership.user_id)
        raise Denied, "An independent reviewer must approve this document."
      end

      if outcome.to_s == "changes_requested" && comments.to_s.strip.blank?
        raise InvalidState, "Explain what needs to change."
      end

      Document.transaction do
        locked = Document.lock.find(document.id)
        locked_version = DocumentVersion.lock.find(version.id)
        raise InvalidState, "This version does not belong to the document." unless locked_version.document_id == locked.id
        raise InvalidState, "Submit the document for review first." unless locked.workflow_status == "submitted"
        raise InvalidState, "Security checks must finish successfully before review." unless locked_version.downloadable?

        review = DocumentReview.create!(
          document_version: locked_version,
          reviewer_membership: @membership,
          outcome: outcome.to_s,
          comments: comments.to_s.strip.presence,
          decided_at: Time.current
        )

        case outcome.to_s
        when "approved"
          locked.update!(workflow_status: "approved")
          audit = Documents::Audit.review_approved(document: locked, version: locked_version, review: review, actor_membership: @membership)
          Notifications::StaffPublisher.document_approved(document: locked, audit_event: audit, actor: @membership)
        when "changes_requested"
          locked.update!(workflow_status: "changes_requested")
          if locked.upload_request.present?
            locked.upload_request.update!(status: "changes_required")
          end
          audit = Documents::Audit.review_changes_requested(document: locked, version: locked_version, review: review, actor_membership: @membership)
          Notifications::StaffPublisher.document_changes_requested(document: locked, audit_event: audit, actor: @membership)
        end

        Result.new(document: locked, review: review)
      end
    end
  end
end
