# frozen_string_literal: true

module Reports
  class Review
    Result = Data.define(:report, :version, :review)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    OUTCOMES = %w[approved changes_requested].freeze

    def self.call(membership:, report:, version:, outcome:, comments: nil)
      new(membership: membership).call(report: report, version: version, outcome: outcome, comments: comments)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(report:, version:, outcome:, comments:)
      raise Denied, "You are not allowed to review this report." unless Reports::Access.can_review?(@membership, report)
      raise InvalidState, "Choose approve or request changes." unless OUTCOMES.include?(outcome.to_s)
      raise InvalidState, "This version does not belong to the report." unless version.report_id == report.id
      raise InvalidState, "Submit the report for review first." unless version.status == "submitted_for_review"

      if self_or_material_editor?(version)
        raise Denied, "An independent reviewer must approve this report."
      end

      if outcome.to_s == "changes_requested" && comments.to_s.strip.blank?
        raise InvalidState, "Explain what needs to change."
      end

      review = nil
      locked_version = nil
      Report.transaction do
        locked = Report.lock.find(report.id)
        locked_version = ReportVersion.lock.find(version.id)
        raise InvalidState, "Submit the report for review first." unless locked_version.status == "submitted_for_review"

        review = ReportReview.create!(
          report_version: locked_version,
          reviewer_membership: @membership,
          outcome: outcome.to_s,
          comments: comments.to_s.strip.presence,
          decided_at: Time.current
        )

        case outcome.to_s
        when "approved"
          pdf_bytes = Reports::PdfRenderer.render(report: locked, version: locked_version)
          asset = Reports::ArtifactStore.persist_pdf!(
            membership: @membership,
            organization: locked.operating_organization,
            pdf_bytes: pdf_bytes,
            filename: "#{locked.reference_number}-v#{locked_version.version_number}.pdf"
          )
          locked_version.update!(
            status: "approved",
            storage_asset: asset,
            artifact_checksum_sha256: asset.checksum_sha256
          )
          audit = Reports::Audit.review_approved(report: locked, version: locked_version, review: review, actor_membership: @membership)
          Notifications::StaffPublisher.report_approved(report: locked, audit_event: audit, actor: @membership)
        when "changes_requested"
          locked_version.update!(status: "changes_requested")
          audit = Reports::Audit.review_changes_requested(report: locked, version: locked_version, review: review, actor_membership: @membership)
          Notifications::StaffPublisher.report_changes_requested(report: locked, audit_event: audit, actor: @membership)
        end
      end

      Result.new(report: report.reload, version: locked_version.reload, review: review)
    rescue Reports::ArtifactStore::Error, Prawn::Errors::CannotFit, Prawn::Errors::UnknownOption => e
      raise InvalidState, "The report PDF could not be generated. Approval was not recorded. (#{e.message})"
    end

    private

      def self_or_material_editor?(version)
        actor_user_id = @membership.user_id
        return true if version.authored_by_membership_id == @membership.id
        return true if version.submitted_by_membership_id == @membership.id
        return true if version.authored_by_membership&.user_id == actor_user_id
        return true if version.submitted_by_membership&.user_id == actor_user_id

        editor_ids = Array(version.content_json.is_a?(Hash) ? version.content_json["material_editor_membership_ids"] : []).map(&:to_i)
        return true if editor_ids.include?(@membership.id)

        return false if editor_ids.empty?

        Membership.where(id: editor_ids, user_id: actor_user_id).exists?
      end
  end
end
