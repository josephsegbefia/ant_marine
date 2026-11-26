# frozen_string_literal: true

module Reports
  class Release
    Result = Data.define(:report, :release)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.available?
      !Rails.env.production?
    end

    def self.call(membership:, report:, version:, confirmation: false)
      new(membership: membership).call(report: report, version: version, confirmation: confirmation)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(report:, version:, confirmation:)
      raise Denied, "Client report release is not available in production yet." unless self.class.available?
      raise Denied, "You are not allowed to release this report." unless Reports::Access.can_release?(@membership, report)
      raise Denied, "Simulated report release is not available in production." if Rails.env.production? && report.project.simulated?
      raise Error, "Confirm that this exact version should be shared with the client." unless ActiveModel::Type::Boolean.new.cast(confirmation)
      raise InvalidState, "This version does not belong to the report." unless version.report_id == report.id
      raise InvalidState, "Approve this exact version before releasing it." unless version.approved?
      raise InvalidState, "The approved PDF must be ready before release." if version.artifact_checksum_sha256.blank?

      release_record = nil
      Report.transaction do
        locked = Report.lock.find(report.id)
        locked_version = ReportVersion.lock.find(version.id)
        raise InvalidState, "Approve this exact version before releasing it." unless locked_version.approved?

        active = locked.report_releases.active.lock.first
        raise InvalidState, "Revoke the current client release before sharing a different version." if active && active.report_version_id != locked_version.id
        return Result.new(report: locked, release: active) if active&.report_version_id == locked_version.id

        release_record = ReportRelease.create!(
          report: locked,
          report_version: locked_version,
          client_organization: locked.client_organization,
          released_by_membership: @membership,
          released_at: Time.current,
          artifact_checksum_sha256: locked_version.artifact_checksum_sha256
        )
        audit = Reports::Audit.released(report: locked, version: locked_version, release: release_record, actor_membership: @membership)
        Notifications::StaffPublisher.report_released(report: locked, audit_event: audit, actor: @membership)
        Delivery::TechnicalProgress.sync!(project: locked.project)
      end

      Result.new(report: report.reload, release: release_record)
    end
  end
end
