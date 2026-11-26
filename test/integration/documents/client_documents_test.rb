# frozen_string_literal: true

require "test_helper"

class Documents::ClientDocumentsTest < ActionDispatch::IntegrationTest
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    package = build_accepted_project!(staff: @staff, owner: @client)
    @project = package[:project]
  end

  test "client submits request cannot see internal released revoked denies download" do
    request = Documents::CreateUploadRequest.call(
      membership: @staff,
      project: @project,
      title: "Class certificates",
      document_category: "vessel_records"
    ).upload_request

    sign_in_as(@client.user, membership: @client)
    file = Rack::Test::UploadedFile.new(StringIO.new("class cert"), "text/plain", original_filename: "cert.txt")
    post submit_client_project_upload_request_path(@project, request), params: {
      upload: { file: file, title: "Our certificates" }
    }
    client_document = Document.order(:id).last
    assert_redirected_to client_project_document_path(@project, client_document)

    internal = staff_upload_internal!
    perform_enqueued_jobs only: ScanStorageAssetJob

    get client_project_document_path(@project, internal)
    assert_redirected_to root_path

    sign_in_as(@staff.user, membership: @staff)
    release_document!(client_document)

    sign_in_as(@client.user, membership: @client)
    get download_client_project_document_path(@project, client_document)
    assert_response :success

    sign_in_as(@staff.user, membership: @staff)
    release = client_document.reload.active_release
    Documents::RevokeRelease.call(membership: @staff, release: release, reason: "Sent wrong file by mistake.")

    sign_in_as(@client.user, membership: @client)
    get download_client_project_document_path(@project, client_document)
    assert_response :not_found
  end

  private

    def staff_upload_internal!
      file = Rack::Test::UploadedFile.new(StringIO.new("internal only"), "text/plain", original_filename: "internal.txt")
      sign_in_as(@staff.user, membership: @staff)
      post staff_project_documents_path(@project), params: {
        document: {
          title: "Internal memo",
          category: "field_notes",
          classification: "standard",
          visibility_intent: "internal",
          file: file
        }
      }
      Document.order(:id).last
    end

    def release_document!(document)
      perform_enqueued_jobs only: ScanStorageAssetJob
      if document.workflow_status.in?(%w[working_draft changes_requested])
        Documents::SubmitForReview.call(membership: @staff, document: document)
      end
      document.update!(workflow_status: "approved") unless document.approval_required?
      version = document.reload.current_version
      document.reload
      Documents::Release.call(membership: @staff, document: document, version: version, confirmation: true)
    end
end
