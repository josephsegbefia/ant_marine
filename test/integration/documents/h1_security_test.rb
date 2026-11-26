# frozen_string_literal: true

require "test_helper"

class Documents::H1SecurityTest < ActionDispatch::IntegrationTest
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @project = build_accepted_project!(staff: @staff, owner: @client)[:project]
  end

  test "scanner error fails closed with rejected asset and denied download" do
    sign_in_as(@staff.user, membership: @staff)
    document = staff_upload!(bytes: "scan-me", title: "Error scan target")
    version = document.current_version
    asset = version.storage_asset

    error_result = Storage::MalwareScanner::Result.new(status: :error, detail: "stub_scan_failed", adapter: "test_stub")
    with_malware_scan_result(error_result) do
      perform_enqueued_jobs only: ScanStorageAssetJob
    end

    assert_equal "rejected", asset.reload.scan_status
    assert_equal "test_stub", asset.scanner_adapter

    get download_staff_project_document_version_path(@project, document, version)
    assert_redirected_to root_path
  end

  test "client cannot view for_client_release metadata without active release" do
    sign_in_as(@staff.user, membership: @staff)
    document = staff_upload!(
      bytes: "not released yet",
      title: "Awaiting release",
      visibility_intent: "for_client_release",
      category: "vessel_records"
    )
    perform_enqueued_jobs only: ScanStorageAssetJob

    sign_in_as(@client.user, membership: @client)
    get client_project_document_path(@project, document)
    assert_response :not_found
  end

  test "after revoke client download denied" do
    sign_in_as(@staff.user, membership: @staff)
    document = staff_upload!(
      bytes: "released-bytes",
      title: "Client pack",
      visibility_intent: "for_client_release",
      category: "vessel_records"
    )
    perform_enqueued_jobs only: ScanStorageAssetJob
    release = Documents::Release.call(
      membership: @staff,
      document: document,
      version: document.current_version,
      confirmation: true
    ).release

    sign_in_as(@client.user, membership: @client)
    get download_client_project_document_path(@project, document)
    assert_response :success

    sign_in_as(@staff.user, membership: @staff)
    Documents::RevokeRelease.call(membership: @staff, release: release, reason: "Shared in error")

    sign_in_as(@client.user, membership: @client)
    get download_client_project_document_path(@project, document)
    assert_response :not_found
  end

  test "collaborator grant gates metadata and download follows availability" do
    sign_in_as(@staff.user, membership: @staff)
    document = staff_upload!(bytes: "grant-gated", title: "Internal brief", visibility_intent: "internal", category: "field_notes")
    version = document.current_version
    collaborator = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: collaborator,
      assignment_kind: "collaborator",
      access_scope: "collaborator"
    )

    sign_in_as(collaborator.user, membership: collaborator)
    get staff_project_document_path(@project, document)
    assert_redirected_to root_path

    DocumentAccessGrant.create!(
      document: document,
      user: collaborator.user,
      granted_by_membership: @staff
    )

    get staff_project_document_path(@project, document)
    assert_response :success

    get download_staff_project_document_version_path(@project, document, version)
    assert_redirected_to root_path

    sign_in_as(@staff.user, membership: @staff)
    perform_enqueued_jobs only: ScanStorageAssetJob

    sign_in_as(collaborator.user, membership: collaborator)
    document.reload
    get download_staff_project_document_version_path(@project, document, document.current_version)
    assert_response :success
    assert_equal "grant-gated", response.body
  end

  test "cross organisation grant creation fails validation" do
    sign_in_as(@staff.user, membership: @staff)
    document = staff_upload!(bytes: "org-bound", title: "Org scoped")
    perform_enqueued_jobs only: ScanStorageAssetJob
    stranger = create_staff_membership!(role_key: "staff.surveyor", email: "cross-grant-#{SecureRandom.hex(3)}@example.com")

    grant = DocumentAccessGrant.new(
      document: document,
      user: stranger.user,
      granted_by_membership: @client
    )
    assert_not grant.valid?
    assert grant.errors[:document].any?
  end

  test "assignment revocation denies document download url" do
    surveyor = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: surveyor,
      assignment_kind: "surveyor",
      access_scope: "delivery"
    )

    sign_in_as(@staff.user, membership: @staff)
    document = staff_upload!(bytes: "team-file", title: "Team file")
    version = document.current_version
    perform_enqueued_jobs only: ScanStorageAssetJob

    sign_in_as(surveyor.user, membership: surveyor)
    get download_staff_project_document_version_path(@project, document, version)
    assert_response :success

    assignment = @project.active_assignment_for(surveyor.user)
    Delivery::Unassign.call(actor_membership: @staff, assignment: assignment, reason: "left the job")

    get download_staff_project_document_version_path(@project, document, version)
    assert_response :not_found
  end

  test "confidential download denied without documents access confidential permission" do
    surveyor = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: surveyor,
      assignment_kind: "surveyor",
      access_scope: "delivery"
    )

    sign_in_as(@staff.user, membership: @staff)
    document = staff_upload!(
      bytes: "top secret",
      title: "Confidential memo",
      classification: "confidential"
    )
    version = document.current_version
    perform_enqueued_jobs only: ScanStorageAssetJob

    sign_in_as(surveyor.user, membership: surveyor)
    get download_staff_project_document_version_path(@project, document, version)
    assert_redirected_to root_path
  end

  test "active storage blob route still returns not found" do
    get "/rails/active_storage/blobs/redirect/00000000-0000-0000-0000-000000000000"
    assert_response :not_found
  end

  private

    def staff_upload!(bytes:, title:, visibility_intent: "internal", category: "other", classification: "standard")
      file = Rack::Test::UploadedFile.new(StringIO.new(bytes), "text/plain", original_filename: "#{title.parameterize}.txt")
      post staff_project_documents_path(@project), params: {
        document: {
          title: title,
          category: category,
          classification: classification,
          visibility_intent: visibility_intent,
          file: file
        }
      }
      assert_response :redirect
      Document.order(:id).last
    end
end
