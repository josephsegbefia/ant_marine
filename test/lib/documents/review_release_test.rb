# frozen_string_literal: true

require "test_helper"

class Documents::ReviewReleaseTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
    @reviewer = create_staff_membership!(role_key: "staff.technical_reviewer")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: @reviewer,
      assignment_kind: "technical_reviewer",
      access_scope: "review"
    )
  end

  test "submit review approve and release enforce exact version" do
    result = Documents::Upload.call(
      membership: @staff,
      project: @project,
      filename: "report.txt",
      io: StringIO.new("version one"),
      title: "Report data",
      category: "report_supporting"
    )
    document = result.document
    perform_enqueued_jobs only: ScanStorageAssetJob
    document.reload

    Documents::SubmitForReview.call(membership: @staff, document: document)
    assert_equal "submitted", document.reload.workflow_status

    v1 = document.current_version
    assert_raises(Documents::Review::Denied) do
      Documents::Review.call(membership: @staff, document: document, version: v1, outcome: "approved")
    end

    Documents::Review.call(membership: @reviewer, document: document, version: v1, outcome: "approved")
    assert_equal "approved", document.reload.workflow_status

    release = Documents::Release.call(
      membership: @staff,
      document: document,
      version: v1,
      confirmation: true
    )
    assert release.release.active?
    assert_equal "released", document.reload.workflow_status

    Documents::Upload.call(
      membership: @staff,
      project: @project,
      filename: "report-v2.txt",
      io: StringIO.new("version two"),
      title: "Report data",
      category: "report_supporting",
      document: document
    )
    perform_enqueued_jobs only: ScanStorageAssetJob
    v2 = document.reload.current_version

    assert_raises(Documents::Release::InvalidState) do
      Documents::Release.call(membership: @staff, document: document, version: v2, confirmation: true)
    end

    Documents::RevokeRelease.call(
      membership: @staff,
      release: release.release,
      reason: "Replace with corrected version."
    )
    assert_not release.release.reload.active?
  end
end
