# frozen_string_literal: true

module Reports
  class Submit
    Result = Data.define(:report, :version)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, report:, version: nil)
      new(membership: membership).call(report: report, version: version)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(report:, version:)
      raise Denied, "You are not allowed to submit this report." unless Reports::Access.can_draft?(@membership, report)

      version ||= report.current_version
      raise InvalidState, "Prepare a report version before submitting." unless version
      raise InvalidState, "This version does not belong to the report." unless version.report_id == report.id
      raise InvalidState, "Only a draft version can be submitted for review." unless version.draft?

      sections = version.content_json.is_a?(Hash) ? version.content_json["sections"] : {}
      raise InvalidState, "Add an executive summary before submitting." if sections.is_a?(Hash) && sections["executive_summary"].to_s.strip.blank?

      locked = nil
      Report.transaction do
        locked = ReportVersion.lock.find(version.id)
        raise InvalidState, "Only a draft version can be submitted for review." unless locked.draft?

        locked.update!(
          status: "submitted_for_review",
          submitted_by_membership: @membership
        )
        audit = Reports::Audit.submitted(report: report, version: locked, actor_membership: @membership)
        Notifications::StaffPublisher.report_review_required(report: report, audit_event: audit, actor: @membership)
      end

      Result.new(report: report, version: locked)
    end
  end
end
