# frozen_string_literal: true

module Staff
  class ReportVersionsController < BaseController
    before_action :set_report
    before_action :set_version

    def update
      authorize @version, :update?
      Reports::UpdateDraft.call(
        membership: Current.membership,
        report: @report,
        version: @version,
        title: params.dig(:report_version, :title),
        sections: params.dig(:report_version, :sections)&.to_unsafe_h
      )
      redirect_to staff_report_path(@report), notice: "Draft saved."
    rescue Reports::UpdateDraft::Denied, Reports::UpdateDraft::InvalidState => e
      redirect_to staff_report_path(@report), alert: e.message
    end

    def review
      authorize @version, :review?
      Reports::Review.call(
        membership: Current.membership,
        report: @report,
        version: @version,
        outcome: params.require(:outcome),
        comments: params[:comments]
      )
      redirect_to staff_report_path(@report), notice: "Review recorded."
    rescue Reports::Review::Denied, Reports::Review::InvalidState => e
      redirect_to staff_report_path(@report), alert: e.message
    end

    def release
      authorize @version, :release?
      Reports::Release.call(
        membership: Current.membership,
        report: @report,
        version: @version,
        confirmation: params[:confirm]
      )
      redirect_to staff_report_path(@report), notice: "This version is now available to the client."
    rescue Reports::Release::Denied, Reports::Release::InvalidState, Reports::Release::Error => e
      redirect_to staff_report_path(@report), alert: e.message
    end

    private

      def set_report
        @report = policy_scope(Report).find(params[:report_id])
      end

      def set_version
        @version = @report.report_versions.find(params[:id])
      end
  end
end
