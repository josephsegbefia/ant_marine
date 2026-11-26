# frozen_string_literal: true

module Reports
  class RevokeRelease
    Result = Data.define(:report, :release)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, release:, reason:)
      new(membership: membership).call(release: release, reason: reason)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(release:, reason:)
      raise Denied, "You are not allowed to revoke this release." unless Reports::Access.can_release?(@membership, release.report)
      raise InvalidState, "This release is already revoked." unless release.active?
      raise InvalidState, "Explain why client access should be withdrawn." if reason.to_s.strip.blank?

      Report.transaction do
        locked_release = ReportRelease.lock.find(release.id)
        raise InvalidState, "This release is already revoked." unless locked_release.active?

        locked_release.update!(
          revoked_at: Time.current,
          revocation_reason: reason.to_s.strip
        )
        report = Report.lock.find(locked_release.report_id)
        Reports::Audit.release_revoked(report: report, release: locked_release, actor_membership: @membership)
        Result.new(report: report, release: locked_release)
      end
    end
  end
end
