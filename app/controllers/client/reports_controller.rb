# frozen_string_literal: true

module Client
  class ReportsController < BaseController
    PER_PAGE = 25
    before_action :set_report, only: %i[show download]

    def index
      authorize Report
      scope = policy_scope(Report).includes(:project, :current_version)
      @pagination = Pagination.new(scope.order(updated_at: :desc, id: :desc), page: params[:page], per_page: PER_PAGE)
      @reports = @pagination.records
    end

    def show
      authorize @report
      @release = @report.report_releases.active.find_by(client_organization_id: Current.membership.organization_id)
      @version = @release&.report_version
    end

    def download
      authorize @report, :download?
      release = @report.report_releases.active.find_by!(client_organization_id: Current.membership.organization_id)
      payload = Reports::SecureDownload.call(membership: Current.membership, version: release.report_version)
      response.headers["Cache-Control"] = "no-store"
      send_data payload.plaintext, filename: payload.filename, type: payload.content_type, disposition: "attachment"
    rescue Reports::SecureDownload::Denied, Reports::SecureDownload::Error
      head :not_found
    end

    private

      def set_report
        @report = policy_scope(Report).find(params[:id])
      end
  end
end
