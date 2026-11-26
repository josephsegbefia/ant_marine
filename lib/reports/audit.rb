# frozen_string_literal: true

module Reports
  module Audit
    module_function

    def prepared(report:, version:, actor_membership:)
      record(
        "reports.prepared",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: base_meta(report, version)
      )
    end

    def draft_updated(report:, version:, actor_membership:)
      record(
        "reports.draft_updated",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: base_meta(report, version)
      )
    end

    def submitted(report:, version:, actor_membership:)
      record(
        "reports.submitted_for_review",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: base_meta(report, version)
      )
    end

    def revised(report:, version:, predecessor:, actor_membership:)
      record(
        "reports.revised",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: base_meta(report, version).merge(
          "predecessor_version_id" => predecessor.id,
          "predecessor_version_number" => predecessor.version_number
        )
      )
    end

    def review_approved(report:, version:, review:, actor_membership:)
      record(
        "reports.review_approved",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: base_meta(report, version).merge("report_review_id" => review.id)
      )
    end

    def review_changes_requested(report:, version:, review:, actor_membership:)
      record(
        "reports.review_changes_requested",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: base_meta(report, version).merge("report_review_id" => review.id)
      )
    end

    def released(report:, version:, release:, actor_membership:)
      record(
        "reports.released",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: base_meta(report, version).merge("report_release_id" => release.id)
      )
    end

    def release_revoked(report:, release:, actor_membership:)
      record(
        "reports.release_revoked",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: {
          "report_id" => report.id,
          "report_release_id" => release.id,
          "project_id" => report.project_id
        }
      )
    end

    def download_allowed(report:, version:, actor_membership:)
      record(
        "reports.download_allowed",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: base_meta(report, version)
      )
    end

    def download_denied(report:, version:, actor_membership:)
      record(
        "reports.download_denied",
        organization: report.operating_organization,
        actor_membership: actor_membership,
        subject: report,
        metadata: base_meta(report, version)
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

    def base_meta(report, version)
      {
        "report_id" => report.id,
        "reference_number" => report.reference_number,
        "report_version_id" => version.id,
        "version_number" => version.version_number,
        "project_id" => report.project_id
      }
    end
  end
end
