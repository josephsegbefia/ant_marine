# frozen_string_literal: true

module Documents
  module Audit
    module_function

    def document_uploaded(document:, version:, actor_membership:)
      audit = record(
        "documents.version_uploaded",
        organization: document.operating_organization,
        actor_membership: actor_membership,
        subject: document,
        metadata: base_meta(document, version).merge(
          "classification" => document.classification,
          "visibility_intent" => document.visibility_intent
        )
      )
      audit
    end

    def upload_requested(upload_request:, actor_membership:)
      audit = record(
        "documents.upload_requested",
        organization: upload_request.operating_organization,
        actor_membership: actor_membership,
        subject: upload_request,
        metadata: {
          "upload_request_id" => upload_request.id,
          "project_id" => upload_request.project_id,
          "document_category" => upload_request.document_category
        }
      )
      audit
    end

    def submitted_for_review(document:, version:, actor_membership:)
      audit = record(
        "documents.submitted_for_review",
        organization: document.operating_organization,
        actor_membership: actor_membership,
        subject: document,
        metadata: base_meta(document, version)
      )
      audit
    end

    def review_approved(document:, version:, review:, actor_membership:)
      audit = record(
        "documents.review_approved",
        organization: document.operating_organization,
        actor_membership: actor_membership,
        subject: document,
        metadata: base_meta(document, version).merge("document_review_id" => review.id)
      )
      audit
    end

    def review_changes_requested(document:, version:, review:, actor_membership:)
      audit = record(
        "documents.review_changes_requested",
        organization: document.operating_organization,
        actor_membership: actor_membership,
        subject: document,
        metadata: base_meta(document, version).merge("document_review_id" => review.id)
      )
      audit
    end

    def released(document:, version:, release:, actor_membership:)
      audit = record(
        "documents.released",
        organization: document.operating_organization,
        actor_membership: actor_membership,
        subject: document,
        metadata: base_meta(document, version).merge(
          "document_release_id" => release.id,
          "client_organization_id" => release.client_organization_id
        )
      )
      audit
    end

    def release_revoked(document:, release:, actor_membership:)
      audit = record(
        "documents.release_revoked",
        organization: document.operating_organization,
        actor_membership: actor_membership,
        subject: document,
        metadata: {
          "document_id" => document.id,
          "document_release_id" => release.id,
          "document_version_id" => release.document_version_id,
          "project_id" => document.project_id
        }
      )
      audit
    end

    def download_allowed(version:, actor_membership:)
      document = version.document
      audit = record(
        "documents.download_allowed",
        organization: document.operating_organization,
        actor_membership: actor_membership,
        subject: document,
        metadata: base_meta(document, version)
      )
      audit
    end

    def download_denied(version:, actor_membership:)
      document = version.document
      record(
        "documents.download_denied",
        organization: document.operating_organization,
        actor_membership: actor_membership,
        subject: document,
        metadata: base_meta(document, version)
      )
    end

    def record(event_type, organization:, actor_membership:, subject:, metadata: {})
      AuditEvent.record!(
        event_type: event_type,
        organization: organization,
        actor_membership: actor_membership,
        subject: subject,
        metadata: metadata
      )
    end

    private :record

    def base_meta(document, version)
      {
        "document_id" => document.id,
        "document_version_id" => version.id,
        "version_number" => version.version_number,
        "project_id" => document.project_id,
        "storage_asset_id" => version.storage_asset_id
      }
    end
  end
end
