# frozen_string_literal: true

require "test_helper"

class Documents::StaffDocumentsTest < ActionDispatch::IntegrationTest
  setup do
    @staff = memberships(:ops_manager_membership)
    package = build_accepted_project!(staff: @staff, owner: memberships(:client_owner_membership))
    @project = package[:project]
    sign_in_as(@staff.user, membership: @staff)
  end

  test "staff uploads document with quarantine then downloads after scan" do
    file = upload_file("survey.txt", "field notes content")

    assert_difference [ "Document.count", "DocumentVersion.count" ], 1 do
      post staff_project_documents_path(@project), params: {
        document: {
          title: "Field notes pack",
          category: "field_notes",
          classification: "standard",
          visibility_intent: "internal",
          file: file
        }
      }
    end

    document = Document.order(:id).last
    assert_redirected_to staff_project_document_path(@project, document)
    follow_redirect!
    assert_match(/security checks pending|Uploaded/i, response.body)

    version = document.current_version
    get download_staff_project_document_version_path(@project, document, version)
    assert_redirected_to root_path

    perform_enqueued_jobs only: ScanStorageAssetJob
    document.reload
    assert document.current_version.downloadable?

    get download_staff_project_document_version_path(@project, document, version)
    assert_response :success
    assert_equal "field notes content", response.body
    assert_match(/no-store/i, response.headers["Cache-Control"])
  end

  test "staff submits review approves and releases to client" do
    document = staff_upload!(title: "Certificate pack", category: "certificates")
    perform_enqueued_jobs only: ScanStorageAssetJob

    post submit_for_review_staff_project_document_path(@project, document)
    assert_redirected_to staff_project_document_path(@project, document)

    reviewer = create_staff_membership!(role_key: "staff.technical_reviewer")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: reviewer,
      assignment_kind: "technical_reviewer",
      access_scope: "review"
    )

    sign_in_as(reviewer.user, membership: reviewer)
    version = document.reload.current_version
    post review_staff_project_document_version_path(@project, document, version),
         params: { outcome: "approved", comments: "Looks good." }
    assert_redirected_to staff_project_document_path(@project, document)

    sign_in_as(@staff.user, membership: @staff)
    post release_staff_project_document_version_path(@project, document, version), params: { confirm: "1" }
    assert_redirected_to staff_project_document_path(@project, document)
    assert_equal "released", document.reload.workflow_status
    assert document.active_release?
  end

  private

    def upload_file(name, content)
      Rack::Test::UploadedFile.new(StringIO.new(content), "text/plain", original_filename: name)
    end

    def staff_upload!(title:, category:)
      file = upload_file("#{category}.txt", "uploaded content for #{title}")
      post staff_project_documents_path(@project), params: {
        document: { title: title, category: category, classification: "standard", visibility_intent: "internal", file: file }
      }
      Document.order(:id).last
    end
end
