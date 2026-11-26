# frozen_string_literal: true

require "test_helper"

class Documents::UploadTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
    @client = memberships(:client_owner_membership)
    @stranger = create_staff_membership!(role_key: "staff.surveyor")
  end

  test "staff upload creates document version and enqueues scan" do
    assert_difference [ "Document.count", "DocumentVersion.count", "Storage::Asset.count" ], 1 do
      result = Documents::Upload.call(
        membership: @staff,
        project: @project,
        filename: "survey.txt",
        io: StringIO.new("vessel data"),
        title: "Vessel data pack",
        category: "vessel_records",
        classification: "standard",
        visibility_intent: "internal"
      )
      assert_equal "working_draft", result.document.workflow_status
      assert_equal 1, result.version.version_number
      assert_equal result.version, result.document.current_version
    end

    perform_enqueued_jobs only: ScanStorageAssetJob
    doc = Document.last
    assert_equal "available", doc.current_version.storage_asset.reload.scan_status
    assert AuditEvent.exists?(event_type: "documents.version_uploaded", subject_id: doc.id)
  end

  test "unassigned staff is denied" do
    assert_raises(Documents::Upload::Denied) do
      Documents::Upload.call(
        membership: @stranger,
        project: @project,
        filename: "x.txt",
        io: StringIO.new("nope"),
        title: "Blocked",
        category: "other"
      )
    end
  end

  test "client can submit against open upload request" do
    request = UploadRequest.create!(
      project: @project,
      operating_organization: @project.operating_organization,
      client_organization: @project.client_organization,
      title: "Please send certificates",
      document_category: "certificates",
      status: "requested",
      requested_by_membership: @staff
    )

    result = Documents::Upload.call(
      membership: @client,
      project: @project,
      filename: "certificates.txt",
      io: StringIO.new("class certificate copy"),
      title: "Class certificate",
      category: "certificates",
      upload_request: request
    )

    assert_equal "client_submitted", result.document.visibility_intent
    assert_equal "submitted", result.document.workflow_status
    assert_equal "submitted", request.reload.status
    assert_nil request.satisfied_document_id
  end

  test "new version resets workflow to working draft for staff" do
    first = Documents::Upload.call(
      membership: @staff,
      project: @project,
      filename: "v1.txt",
      io: StringIO.new("one"),
      title: "Draft report pack",
      category: "report_supporting"
    ).document
    first.update!(workflow_status: "approved")

    Documents::Upload.call(
      membership: @staff,
      project: @project,
      filename: "v2.txt",
      io: StringIO.new("two"),
      title: "Draft report pack",
      category: "report_supporting",
      document: first
    )

    assert_equal "working_draft", first.reload.workflow_status
    assert_equal 2, first.document_versions.count
  end
end
