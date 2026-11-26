# frozen_string_literal: true

require "test_helper"

class InspectionsReportsWorkflowTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @project = build_accepted_project!(staff: @staff, owner: @client)[:project]
    @surveyor = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: @surveyor,
      assignment_kind: "surveyor"
    )
    @reviewer = create_staff_membership!(role_key: "staff.technical_reviewer")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: @reviewer,
      assignment_kind: "technical_reviewer",
      access_scope: "review"
    )
  end

  test "create and submit inspection enforces required items" do
    inspection = Inspections::Create.call(
      membership: @staff,
      project: @project,
      title: "Hull walk",
      inspection_type: "general_observation",
      assignee: @surveyor
    ).inspection

    assert_match(/\AANT-INS-\d{4}-\d{5}\z/, inspection.reference_number)

    assert_raises(Inspections::Submit::InvalidState) do
      Inspections::Submit.call(membership: @surveyor, inspection: inspection, confirmation: true)
    end

    %w[hull_visible_damage deck_condition].each do |key|
      type = key == "hull_visible_damage" ? "yes_no_na" : "satisfactory_unsatisfactory"
      answer = key == "hull_visible_damage" ? "no" : "satisfactory"
      Inspections::SaveChecklistResponse.call(
        membership: @surveyor,
        inspection: inspection,
        item_key: key,
        response_type: type,
        value_json: { "answer" => answer }
      )
    end

    submitted = Inspections::Submit.call(membership: @surveyor, inspection: inspection.reload, confirmation: true).inspection
    assert_equal "submitted", submitted.status
  end

  test "attach quarantined evidence denied" do
    inspection = build_inspection!(project: @project, staff: @staff, assignee: @surveyor)
    upload = Documents::Upload.call(
      membership: @staff,
      project: @project,
      filename: "evidence.txt",
      io: StringIO.new("payload"),
      title: "Evidence",
      category: "report_supporting"
    )
    version = upload.version
    version.storage_asset.update!(scan_status: "rejected", rejected_reason: "test")

    assert_raises(Inspections::AttachEvidence::InvalidState) do
      Inspections::AttachEvidence.call(membership: @surveyor, inspection: inspection, document_version: version)
    end
  end

  test "cross project evidence denied" do
    inspection = build_inspection!(project: @project, staff: @staff, assignee: @surveyor)
    other = build_accepted_project!(staff: @staff, idempotency_key: "iso-#{SecureRandom.hex(3)}")[:project]
    upload = Documents::Upload.call(
      membership: @staff,
      project: other,
      filename: "other.txt",
      io: StringIO.new("other"),
      title: "Other",
      category: "report_supporting"
    )
    perform_enqueued_jobs only: ScanStorageAssetJob
  assert_raises(Inspections::AttachEvidence::InvalidState) do
      Inspections::AttachEvidence.call(
        membership: @surveyor,
        inspection: inspection,
        document_version: upload.version.reload
      )
    end
  end

  test "independent approve release and client download" do
    inspection = build_submitted_inspection!
    report = Reports::Prepare.call(membership: @staff, project: @project, inspection: inspection).report
    Reports::UpdateDraft.call(
      membership: @staff,
      report: report,
      version: report.current_version,
      sections: { executive_summary: "Simulated summary for QA." }
    )
    version = report.reload.current_version
    Reports::Submit.call(membership: @staff, report: report, version: version.reload)

    version = report.current_version.reload
    assert_raises(Reports::Review::Denied) do
      Reports::Review.call(membership: @staff, report: report, version: version, outcome: "approved")
    end

    Reports::Review.call(membership: @reviewer, report: report, version: version, outcome: "approved")
    assert version.reload.approved?
    assert version.storage_asset_id.present?

    release = Reports::Release.call(
      membership: @staff,
      report: report,
      version: version,
      confirmation: true
    ).release
    assert release.active?

    payload = Reports::SecureDownload.call(membership: @client, version: version)
    assert_operator payload.plaintext.bytesize, :>, 100

    technical = @project.project_milestones.find_by!(kind: "technical_review")
    assert technical.reload.completed?, "technical_review milestone should complete after inspection submit"
    release_milestone = @project.project_milestones.find_by!(kind: "report_release")
    assert release_milestone.reload.completed?, "report_release milestone should complete after client release"
  end

  test "revoke blocks client download" do
    inspection = build_submitted_inspection!
    report = prepare_approved_report!(inspection)
    version = report.current_version
    release = Reports::Release.call(membership: @staff, report: report, version: version, confirmation: true).release

    Reports::RevokeRelease.call(membership: @staff, release: release, reason: "Withdraw for correction.")
    assert_raises(Reports::SecureDownload::Denied) do
      Reports::SecureDownload.call(membership: @client, version: version)
    end
  end

  test "cross client deny on client report list" do
    inspection = build_submitted_inspection!
    report = prepare_approved_report!(inspection)
    Reports::Release.call(membership: @staff, report: report, version: report.current_version, confirmation: true)

    other_user = User.create!(
      email: "f407-other-#{SecureRandom.hex(3)}@example.com",
      password: "Secure-password-123",
      status: "active",
      full_name: "Other Org Owner"
    )
    stranger = Membership.create!(
      user: other_user,
      organization: organizations(:other_client),
      role_key: "client.org_owner",
      status: "active",
      permission_epoch: 0,
      lock_version: 0,
      accepted_at: Time.current
    )
    assert_not Reports::Access.can_view_metadata?(stranger, report)
  end

  test "correction workflow creates new draft without carrying approval" do
    inspection = build_submitted_inspection!
    report = Reports::Prepare.call(membership: @staff, project: @project, inspection: inspection).report
    Reports::UpdateDraft.call(
      membership: @staff,
      report: report,
      version: report.current_version,
      sections: { executive_summary: "Needs work" }
    )
    version = report.reload.current_version
    Reports::Submit.call(membership: @staff, report: report, version: version.reload)
    Reports::Review.call(
      membership: @reviewer,
      report: report.reload,
      version: report.current_version,
      outcome: "changes_requested",
      comments: "Clarify conclusions."
    )

    revised = Reports::Revise.call(membership: @staff, report: report.reload).version
    assert_equal "draft", revised.status
    assert_equal 2, revised.version_number
    assert_equal 1, revised.content_json.dig("revision", "predecessor_version_number")
    assert_nil revised.artifact_checksum_sha256
    assert_equal revised.id, report.reload.current_version_id
    assert_equal "changes_requested", report.report_versions.find_by!(version_number: 1).status
  end

  test "collaborator cannot approve report" do
    inspection = build_submitted_inspection!
    report = Reports::Prepare.call(membership: @staff, project: @project, inspection: inspection).report
    Reports::UpdateDraft.call(
      membership: @staff,
      report: report,
      version: report.current_version,
      sections: { executive_summary: "Summary" }
    )
    Reports::Submit.call(membership: @staff, report: report, version: report.reload.current_version)

    collaborator = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: collaborator,
      assignment_kind: "collaborator",
      access_scope: "collaborator"
    )

    assert_not Reports::Access.can_review?(collaborator, report)
    assert_raises(Reports::Review::Denied) do
      Reports::Review.call(
        membership: collaborator,
        report: report,
        version: report.current_version,
        outcome: "approved"
      )
    end
  end

  test "newer draft after release stays hidden from client" do
    inspection = build_submitted_inspection!
    report = prepare_approved_report!(inspection)
    approved = report.current_version
    Reports::Release.call(membership: @staff, report: report, version: approved, confirmation: true)

    draft = Reports::Revise.call(membership: @staff, report: report.reload).version
    assert_equal "draft", draft.status
    assert_equal draft.id, report.reload.current_version_id

    payload = Reports::SecureDownload.call(membership: @client, version: approved)
    assert_operator payload.plaintext.bytesize, :>, 100
    assert_raises(Reports::SecureDownload::Denied) do
      Reports::SecureDownload.call(membership: @client, version: draft)
    end
  end

  private

    def build_submitted_inspection!
      inspection = Inspections::Create.call(
        membership: @staff,
        project: @project,
        title: "Walkthrough",
        inspection_type: "general_observation",
        assignee: @surveyor
      ).inspection

      %w[hull_visible_damage deck_condition].each do |key|
        type = key == "hull_visible_damage" ? "yes_no_na" : "satisfactory_unsatisfactory"
        answer = key == "hull_visible_damage" ? "no" : "satisfactory"
        Inspections::SaveChecklistResponse.call(
          membership: @surveyor,
          inspection: inspection,
          item_key: key,
          response_type: type,
          value_json: { "answer" => answer }
        )
      end

      Inspections::Submit.call(membership: @surveyor, inspection: inspection.reload, confirmation: true).inspection
    end

    def prepare_approved_report!(inspection)
      report = Reports::Prepare.call(membership: @staff, project: @project, inspection: inspection).report
      Reports::UpdateDraft.call(
        membership: @staff,
        report: report,
        version: report.current_version,
        sections: { executive_summary: "Summary" }
      )
      version = report.reload.current_version
      Reports::Submit.call(membership: @staff, report: report, version: version.reload)
      Reports::Review.call(
        membership: @reviewer,
        report: report.reload,
        version: report.current_version,
        outcome: "approved"
      )
      report.reload
    end
end
