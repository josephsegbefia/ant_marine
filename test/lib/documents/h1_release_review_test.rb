# frozen_string_literal: true

require "test_helper"

class Documents::H1ReleaseReviewTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @project = build_accepted_project!(staff: @staff, owner: @client)[:project]
    @reviewer = create_staff_membership!(role_key: "staff.technical_reviewer")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: @reviewer,
      assignment_kind: "technical_reviewer",
      access_scope: "review"
    )
  end

  test "approval required document cannot release without review on that version" do
    document = scan_after_upload!(upload_document!(category: "technical_evidence"))
    v1 = document.current_version

    assert_raises(Documents::Release::InvalidState) do
      Documents::Release.call(membership: @staff, document: document, version: v1, confirmation: true)
    end

    Documents::SubmitForReview.call(membership: @staff, document: document)
    assert_raises(Documents::Release::InvalidState) do
      Documents::Release.call(membership: @staff, document: document, version: v1, confirmation: true)
    end
  end

  test "new version after approval does not inherit client release" do
    document = scan_after_upload!(upload_document!(category: "report_supporting", visibility_intent: "for_client_release"))
    Documents::SubmitForReview.call(membership: @staff, document: document.reload)
    v1 = document.reload.current_version
    Documents::Review.call(membership: @reviewer, document: document.reload, version: v1, outcome: "approved")

    release = Documents::Release.call(
      membership: @staff,
      document: document,
      version: v1,
      confirmation: true
    ).release
    assert release.active?

    Documents::Upload.call(
      membership: @staff,
      project: @project,
      filename: "v2.txt",
      io: StringIO.new("version-two"),
      title: document.title,
      category: document.category,
      classification: document.classification,
      visibility_intent: document.visibility_intent,
      document: document
    )
    perform_enqueued_jobs only: ScanStorageAssetJob
    v2 = document.reload.current_version
    assert_not_equal v1.id, v2.id

    assert Documents::Access.can_download_version?(@client, v1)
    assert_not Documents::Access.can_download_version?(@client, v2)

    assert_raises(Documents::Release::InvalidState) do
      Documents::Release.call(membership: @staff, document: document, version: v2, confirmation: true)
    end
  end

  test "upload request stays submitted until release satisfies it" do
    upload_request = Documents::CreateUploadRequest.call(
      membership: @staff,
      project: @project,
      title: "Crew certificates",
      document_category: "certificates"
    ).upload_request

    result = Documents::Upload.call(
      membership: @client,
      project: @project,
      filename: "crew-cert.txt",
      io: StringIO.new("crew data"),
      title: "Our crew certificates",
      category: upload_request.document_category,
      classification: "standard",
      visibility_intent: "client_submitted",
      upload_request: upload_request
    )
    document = scan_after_upload!(result.document)

    upload_request.reload
    assert_equal "submitted", upload_request.status
    assert_nil upload_request.satisfied_document_id

    version = document.current_version
    Documents::Review.call(membership: @reviewer, document: document.reload, version: version, outcome: "approved")
    Documents::Release.call(membership: @staff, document: document, version: version, confirmation: true)

    upload_request.reload
    assert_equal "satisfied", upload_request.status
    assert_equal document.id, upload_request.satisfied_document_id
  end

  private

    def scan_after_upload!(document)
      perform_enqueued_jobs only: ScanStorageAssetJob
      document.reload
    end

    def upload_document!(category:, visibility_intent: "internal")
      Documents::Upload.call(
        membership: @staff,
        project: @project,
        filename: "evidence.txt",
        io: StringIO.new("evidence bytes"),
        title: "Evidence pack",
        category: category,
        visibility_intent: visibility_intent
      ).document
    end
end
