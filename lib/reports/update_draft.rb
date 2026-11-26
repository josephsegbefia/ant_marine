# frozen_string_literal: true

module Reports
  class UpdateDraft
    Result = Data.define(:version)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, report:, version:, title: nil, sections: nil)
      new(membership: membership).call(report: report, version: version, title: title, sections: sections)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(report:, version:, title:, sections:)
      raise Denied, "You are not allowed to edit this report draft." unless Reports::Access.can_draft?(@membership, report)
      raise InvalidState, "This version does not belong to the report." unless version.report_id == report.id
      raise InvalidState, "Only a draft version can be edited." unless version.draft?

      locked = nil
      Report.transaction do
        locked = ReportVersion.lock.find(version.id)
        raise InvalidState, "Only a draft version can be edited." unless locked.draft?

        content = locked.content_json.is_a?(Hash) ? locked.content_json.deep_dup : {}
        if sections.is_a?(Hash)
          content["sections"] ||= {}
          sections.each do |key, value|
            content["sections"][key.to_s] = value.to_s
          end
        end

        locked.update!(
          title: title.to_s.strip.presence || locked.title,
          content_json: content
        )
        report.update!(title: locked.title) if title.present?
        Reports::Audit.draft_updated(report: report, version: locked, actor_membership: @membership)
      end

      Result.new(version: locked)
    end
  end
end
