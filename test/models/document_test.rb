# frozen_string_literal: true

require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
  end

  test "approval required categories are conservative" do
    assert_includes Document::APPROVAL_REQUIRED_CATEGORIES, "technical_evidence"
    assert_not Document::APPROVAL_REQUIRED_CATEGORIES.include?("field_notes")
  end

  test "security status follows current version asset" do
    result = Documents::Upload.call(
      membership: @staff,
      project: @project,
      filename: "scan-me.txt",
      io: StringIO.new("bytes"),
      title: "Scan me",
      category: "other"
    )
    perform_enqueued_jobs only: ScanStorageAssetJob
    doc = result.document.reload
    assert_equal "available", doc.security_status
    assert doc.downloadable?
  end
end
