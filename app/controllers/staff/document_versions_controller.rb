# frozen_string_literal: true

module Staff
  class DocumentVersionsController < BaseController
    before_action :set_project
    before_action :set_document
    before_action :set_version, only: %i[download review release]

    def create
      authorize @document, :upload?
      file = params.require(:document_version).require(:file)
      result = Documents::Upload.call(
        membership: Current.membership,
        project: @project,
        filename: file.original_filename,
        io: file.tempfile,
        title: @document.title,
        category: @document.category,
        classification: @document.classification,
        visibility_intent: @document.visibility_intent,
        document: @document
      )
      redirect_to staff_project_document_path(@project, result.document),
                  notice: "New version uploaded. Security checks will run before download is allowed."
    rescue Documents::Upload::Denied, Documents::Upload::InvalidState, Documents::Upload::Error => e
      redirect_to staff_project_document_path(@project, @document), alert: e.message
    end

    def download
      authorize @version, :download?
      payload = Documents::SecureDownload.call(membership: Current.membership, version: @version)
      response.headers["Cache-Control"] = "no-store"
      response.headers["X-Content-Type-Options"] = "nosniff"
      send_data payload.plaintext,
                filename: payload.filename,
                type: payload.content_type,
                disposition: "attachment"
    rescue Documents::SecureDownload::Denied
      head :not_found
    rescue Documents::SecureDownload::Error
      head :not_found
    end

    def review
      authorize @version, :review?
      Documents::Review.call(
        membership: Current.membership,
        document: @document,
        version: @version,
        outcome: params.require(:outcome),
        comments: params[:comments]
      )
      redirect_to staff_project_document_path(@project, @document), notice: "Review recorded."
    rescue Documents::Review::Denied, Documents::Review::InvalidState, Documents::Review::Error => e
      redirect_to staff_project_document_path(@project, @document), alert: e.message
    end

    def release
      authorize @version, :release?
      Documents::Release.call(
        membership: Current.membership,
        document: @document,
        version: @version,
        confirmation: params[:confirm]
      )
      redirect_to staff_project_document_path(@project, @document), notice: "This version is now shared with the client."
    rescue Documents::Release::Denied, Documents::Release::InvalidState, Documents::Release::Error => e
      redirect_to staff_project_document_path(@project, @document), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end

      def set_document
        @document = policy_scope(Document).where(project_id: @project.id).find(params[:document_id])
      end

      def set_version
        @version = @document.document_versions.find(params[:id])
      end
  end
end
