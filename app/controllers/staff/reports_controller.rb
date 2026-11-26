# frozen_string_literal: true

module Staff
  class ReportsController < BaseController
    PER_PAGE = 25
    before_action :set_report, only: %i[show submit revise pdf]

    def index
      authorize Report
      scope = policy_scope(Report).includes(:project, :current_version)
      @pagination = Pagination.new(scope.order(updated_at: :desc, id: :desc), page: params[:page], per_page: PER_PAGE)
      @reports = @pagination.records
    end

    def show
      authorize @report
      @version = @report.current_version
      @approved_version = @report.report_versions.where(status: "approved").order(version_number: :desc).first
      @releases = @report.report_releases.order(released_at: :desc)
      @reviews = @version&.report_reviews&.includes(:reviewer_membership) || []
    end

    def new
      @project = policy_scope(Project).find(params.require(:project_id))
      @inspection = @project.inspections.find(params.require(:inspection_id))
      authorize Report.new(project: @project), :create?
    end

    def create
      @project = policy_scope(Project).find(params.require(:project_id))
      @inspection = @project.inspections.find(params.require(:inspection_id))
      authorize Report.new(project: @project), :create?
      result = Reports::Prepare.call(
        membership: Current.membership,
        project: @project,
        inspection: @inspection,
        title: params.dig(:report, :title)
      )
      redirect_to staff_report_path(result.report), notice: "Draft report #{result.report.reference_number} prepared."
    rescue Reports::Prepare::Denied, Reports::Prepare::InvalidState => e
      flash[:alert] = e.message
      redirect_to staff_inspection_path(@inspection)
    end

    def submit
      authorize @report, :submit?
      Reports::Submit.call(membership: Current.membership, report: @report)
      redirect_to staff_report_path(@report), notice: "Report submitted for review."
    rescue Reports::Submit::Denied, Reports::Submit::InvalidState => e
      redirect_to staff_report_path(@report), alert: e.message
    end

    def revise
      authorize @report, :revise?
      result = Reports::Revise.call(membership: Current.membership, report: @report)
      redirect_to staff_report_path(result.report), notice: "New draft version #{result.version.version_number} started from the previous review."
    rescue Reports::Revise::Denied, Reports::Revise::InvalidState => e
      redirect_to staff_report_path(@report), alert: e.message
    end

    def pdf
      version = if params[:version_id].present?
        @report.report_versions.find(params[:version_id])
      else
        @report.report_versions.where(status: "approved").order(version_number: :desc).first ||
          @report.current_version
      end
      authorize version, :download?
      payload = Reports::SecureDownload.call(membership: Current.membership, version: version)
      send_data payload.plaintext, filename: payload.filename, type: payload.content_type, disposition: "inline"
    rescue Reports::SecureDownload::Denied, Reports::SecureDownload::Error
      head :not_found
    end

    private

      def set_report
        @report = policy_scope(Report).find(params[:id])
      end
  end
end
