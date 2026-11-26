# frozen_string_literal: true

module Staff
  class ProjectUploadRequestsController < BaseController
    before_action :set_project

    def create
      authorize UploadRequest.new(project: @project), :create?
      result = Documents::CreateUploadRequest.call(
        membership: Current.membership,
        project: @project,
        title: request_params[:title],
        document_category: request_params[:document_category],
        instructions: request_params[:instructions],
        due_on: request_params[:due_on]
      )
      redirect_to staff_project_documents_path(@project),
                  notice: "The client can now see this file request: #{result.upload_request.title}"
    rescue Documents::CreateUploadRequest::Denied, Documents::CreateUploadRequest::InvalidState, Documents::CreateUploadRequest::Error => e
      redirect_to staff_project_documents_path(@project), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end

      def request_params
        params.require(:upload_request).permit(:title, :document_category, :instructions, :due_on)
      end
  end
end
