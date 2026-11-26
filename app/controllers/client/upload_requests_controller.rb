# frozen_string_literal: true

module Client
  class UploadRequestsController < BaseController
    before_action :set_project
    before_action :set_upload_request, only: %i[show submit]

    def index
      authorize @project
      @requests = UploadRequest.where(
        project_id: @project.id,
        client_organization_id: Current.membership.organization_id
      ).order(created_at: :desc)
    end

    def show
      authorize @upload_request
    end

    def submit
      authorize @upload_request, :submit?
      file = params.require(:upload).require(:file)
      result = Documents::Upload.call(
        membership: Current.membership,
        project: @project,
        filename: file.original_filename,
        io: file.tempfile,
        title: params.dig(:upload, :title).presence || @upload_request.title,
        category: @upload_request.document_category,
        classification: params.dig(:upload, :classification).presence || "standard",
        visibility_intent: "client_submitted",
        description: params.dig(:upload, :description),
        upload_request: @upload_request
      )
      redirect_to client_project_document_path(@project, result.document),
                  notice: "Thank you. Your file was uploaded and will be checked before staff can use it."
    rescue Documents::Upload::Denied, Documents::Upload::InvalidState, Documents::Upload::Error => e
      redirect_to client_project_upload_request_path(@project, @upload_request), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end

      def set_upload_request
        @upload_request = UploadRequest.where(
          project_id: @project.id,
          client_organization_id: Current.membership.organization_id
        ).find(params[:id])
      end
  end
end
