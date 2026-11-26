# frozen_string_literal: true

module Client
  class DocumentsController < BaseController
    def index
      authorize Document
      org_id = Current.membership.organization_id
      released = policy_scope(Document).includes(:project, :current_version)
                                       .where(client_organization_id: org_id, workflow_status: "released")
      @open_requests = UploadRequest.where(client_organization_id: org_id).open_for_client.includes(:project)
      @released_documents = released.order(updated_at: :desc).select { |doc| Documents::Access.can_view_metadata?(Current.membership, doc) }
    end
  end
end
