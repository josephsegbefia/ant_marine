# frozen_string_literal: true

module Staff
  class DocumentReleasesController < BaseController
    before_action :set_project
    before_action :set_document
    before_action :set_release

    def revoke
      authorize @release, :revoke?
      Documents::RevokeRelease.call(
        membership: Current.membership,
        release: @release,
        reason: params.require(:reason)
      )
      redirect_to staff_project_document_path(@project, @document), notice: "Client access withdrawn."
    rescue Documents::RevokeRelease::Denied, Documents::RevokeRelease::InvalidState, Documents::RevokeRelease::Error => e
      redirect_to staff_project_document_path(@project, @document), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end

      def set_document
        @document = policy_scope(Document).where(project_id: @project.id).find(params[:document_id])
      end

      def set_release
        @release = @document.document_releases.find(params[:id])
      end
  end
end
