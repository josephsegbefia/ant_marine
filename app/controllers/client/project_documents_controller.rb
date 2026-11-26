# frozen_string_literal: true

module Client
  class ProjectDocumentsController < BaseController
    before_action :set_project
    before_action :set_document, only: %i[show download]

    def index
      authorize Document
      raise ActiveRecord::RecordNotFound unless Documents::Access.can_list_project_documents?(Current.membership, @project)

      @documents = Documents::Access.visible_documents_for_project(Current.membership, @project)
                                   .includes(current_version: :storage_asset)
                                   .order(updated_at: :desc)
      @open_requests = UploadRequest.where(project_id: @project.id, client_organization_id: Current.membership.organization_id)
                                  .open_for_client
    end

    def show
      authorize @document
      @version = downloadable_version
    end

    def download
      version = downloadable_version
      raise ActiveRecord::RecordNotFound unless version

      authorize version, :download?
      payload = Documents::SecureDownload.call(membership: Current.membership, version: version)
      response.headers["Cache-Control"] = "no-store"
      response.headers["X-Content-Type-Options"] = "nosniff"
      send_data payload.plaintext,
                filename: payload.filename,
                type: payload.content_type,
                disposition: "attachment"
    rescue Documents::SecureDownload::Denied
      head :not_found
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end

      def set_document
        @document = policy_scope(Document).where(project_id: @project.id).find(params[:id])
      end

      def downloadable_version
        release = @document.document_releases.active.find_by(client_organization_id: Current.membership.organization_id)
        return release.document_version if release

        version = @document.current_version
        if @document.visibility_intent == "client_submitted" &&
           version&.uploaded_by_membership&.organization_id == Current.membership.organization_id
          version
        end
      end
  end
end
