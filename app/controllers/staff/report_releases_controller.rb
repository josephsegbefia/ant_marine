# frozen_string_literal: true

module Staff
  class ReportReleasesController < BaseController
    before_action :set_report

    def revoke
      release = @report.report_releases.find(params[:id])
      authorize release.report, :release?
      Reports::RevokeRelease.call(
        membership: Current.membership,
        release: release,
        reason: params.require(:reason)
      )
      redirect_to staff_report_path(@report), notice: "Client access to this report was withdrawn."
    rescue Reports::RevokeRelease::Denied, Reports::RevokeRelease::InvalidState => e
      redirect_to staff_report_path(@report), alert: e.message
    end

    private

      def set_report
        @report = policy_scope(Report).find(params[:report_id])
      end
  end
end
