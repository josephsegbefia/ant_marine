# frozen_string_literal: true

module Reports
  # Creates a new draft ReportVersion after corrections or for a post-approval revision.
  # Never mutates approved content or carries prior approval into the new version.
  class Revise
    Result = Data.define(:report, :version)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    REVISABLE = %w[changes_requested approved].freeze

    def self.call(membership:, report:, version: nil)
      new(membership: membership).call(report: report, version: version)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(report:, version:)
      raise Denied, "You are not allowed to prepare a correction for this report." unless Reports::Access.can_draft?(@membership, report)

      version ||= report.current_version
      raise InvalidState, "Prepare a report version before revising." unless version
      raise InvalidState, "This version does not belong to the report." unless version.report_id == report.id
      raise InvalidState, "Start a new version only after changes are requested or the previous version is approved." unless REVISABLE.include?(version.status)

      if report.report_versions.exists?(status: "draft")
        raise InvalidState, "Finish or discard the open draft version before starting another."
      end

      new_version = nil
      Report.transaction do
        locked_report = Report.lock.find(report.id)
        locked_source = ReportVersion.lock.find(version.id)
        raise InvalidState, "Start a new version only after changes are requested or the previous version is approved." unless REVISABLE.include?(locked_source.status)

        next_number = locked_report.report_versions.maximum(:version_number).to_i + 1
        content = locked_source.content_json.is_a?(Hash) ? locked_source.content_json.deep_dup : {}
        content["revision"] = {
          "predecessor_version_id" => locked_source.id,
          "predecessor_version_number" => locked_source.version_number,
          "started_at" => Time.current.iso8601
        }

        new_version = locked_report.report_versions.create!(
          version_number: next_number,
          status: "draft",
          title: locked_source.title,
          content_json: content,
          authored_by_membership: @membership
        )
        locked_report.update!(current_version_id: new_version.id)
        Reports::Audit.revised(report: locked_report, version: new_version, predecessor: locked_source, actor_membership: @membership)
      end

      Result.new(report: report.reload, version: new_version)
    end
  end
end
