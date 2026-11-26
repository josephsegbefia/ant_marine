# frozen_string_literal: true

require "test_helper"

class Documents::QuarantineAndHistoryTest < ActionDispatch::IntegrationTest
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @project = build_accepted_project!(staff: @staff, owner: @client)[:project]
  end

  test "quarantined version cannot be downloaded and version identity is protected" do
    sign_in_as(@staff.user, membership: @staff)
    file = Rack::Test::UploadedFile.new(StringIO.new("pending-bytes"), "text/plain", original_filename: "pending.txt")
    post staff_project_documents_path(@project), params: {
      document: {
        title: "Pending scan file",
        category: "other",
        classification: "standard",
        visibility_intent: "internal",
        file: file
      }
    }
    assert_response :redirect
    document = Document.order(:id).last
    version = document.current_version
    assert_equal "pending_upload", version.storage_asset.scan_status

    get download_staff_project_document_version_path(@project, document, version)
    assert_response :not_found

    ActiveRecord::Base.connection.transaction(requires_new: true) do
      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.connection.execute(
          "UPDATE document_versions SET checksum_sha256 = 'tampered' WHERE id = #{version.id}"
        )
      end
      raise ActiveRecord::Rollback
    end

    perform_enqueued_jobs only: ScanStorageAssetJob
    version.storage_asset.reload
    assert_equal "available", version.storage_asset.scan_status

    get download_staff_project_document_version_path(@project, document, version)
    assert_response :success
    assert_equal "pending-bytes", response.body
    assert_includes response.get_header("Cache-Control").to_s, "no-store"
  end

  test "assignment revocation denies later document access" do
    surveyor = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: surveyor,
      assignment_kind: "surveyor",
      access_scope: "delivery"
    )

    sign_in_as(@staff.user, membership: @staff)
    file = Rack::Test::UploadedFile.new(StringIO.new("team-file"), "text/plain", original_filename: "team.txt")
    post staff_project_documents_path(@project), params: {
      document: {
        title: "Team file",
        category: "other",
        classification: "standard",
        visibility_intent: "internal",
        file: file
      }
    }
    document = Document.order(:id).last
    perform_enqueued_jobs only: ScanStorageAssetJob

    sign_in_as(surveyor.user, membership: surveyor)
    get staff_project_document_path(@project, document)
    assert_response :success

    assignment = @project.active_assignment_for(surveyor.user)
    Delivery::Unassign.call(actor_membership: @staff, assignment: assignment, reason: "left the job")

    get staff_project_document_path(@project, document)
    assert_response :not_found
  end

  test "release revocation blocks client download of that exact version" do
    sign_in_as(@staff.user, membership: @staff)
    file = Rack::Test::UploadedFile.new(StringIO.new("released-bytes"), "text/plain", original_filename: "rel.txt")
    post staff_project_documents_path(@project), params: {
      document: {
        title: "Client pack",
        category: "vessel_records",
        classification: "standard",
        visibility_intent: "for_client_release",
        file: file
      }
    }
    document = Document.order(:id).last
    perform_enqueued_jobs only: ScanStorageAssetJob
    version = document.current_version
    release = Documents::Release.call(
      membership: @staff,
      document: document,
      version: version,
      confirmation: true
    ).release

    sign_in_as(@client.user, membership: @client)
    get download_client_project_document_path(@project, document)
    assert_response :success
    assert_equal "released-bytes", response.body

    Documents::RevokeRelease.call(membership: @staff, release: release, reason: "Shared in error")

    get download_client_project_document_path(@project, document)
    assert_response :not_found
  end
end
