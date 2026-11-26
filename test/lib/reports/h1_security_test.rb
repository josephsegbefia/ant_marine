# frozen_string_literal: true

require "test_helper"

class ReportsH1SecurityTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @project = build_accepted_project!(staff: @staff, owner: @client, idempotency_key: "f407-h1-#{SecureRandom.hex(3)}")[:project]
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

  test "ordinary mark_available cannot claim application_generated provenance" do
    upload = Documents::Upload.call(
      membership: @staff,
      project: @project,
      filename: "notes.txt",
      io: StringIO.new("notes"),
      title: "Notes",
      category: "report_supporting"
    )
    asset = upload.version.storage_asset
    assert_raises(ArgumentError) do
      asset.mark_available!(scan_result: "clean", scanner_adapter: "application_generated")
    end
  end

  test "approved pdf bytes stay stable after later project edits and revision draft" do
    inspection = submit_inspection!
    report = prepare_and_approve!(inspection)
    version = report.current_version
    original_digest = version.artifact_checksum_sha256
    original_bytes = Reports::SecureDownload.call(membership: @staff, version: version).plaintext

    @project.update!(title: "#{@project.title} — post-approval edit")
    Reports::Revise.call(membership: @staff, report: report.reload)
    later_bytes = Reports::SecureDownload.call(membership: @staff, version: version.reload).plaintext

    assert_equal original_digest, version.artifact_checksum_sha256
    assert_equal Digest::SHA256.hexdigest(original_bytes), Digest::SHA256.hexdigest(later_bytes)
    # Prawn encodes the watermark as PDF hex strings (S I M U L A T E D).
    assert_includes original_bytes.upcase, "53494D554C41"

    evidence_dir = Rails.root.join("tmp/f407_h1_screens")
    FileUtils.mkdir_p(evidence_dir)
    File.binwrite(evidence_dir.join("approved_report_sample.pdf"), original_bytes)
  end

  test "material editor cannot approve the version they edited" do
    inspection = submit_inspection!
    report = Reports::Prepare.call(membership: @staff, project: @project, inspection: inspection).report
    Reports::UpdateDraft.call(
      membership: @surveyor,
      report: report,
      version: report.current_version,
      sections: { executive_summary: "Edited by surveyor." }
    )
    version = report.reload.current_version
    assert_includes Array(version.content_json["material_editor_membership_ids"]), @surveyor.id

    # Record the independent reviewer as a material editor before submit (same person SoD).
    content = version.content_json.deep_dup
    content["material_editor_membership_ids"] = Array(content["material_editor_membership_ids"]).map(&:to_i) | [ @reviewer.id ]
    version.update!(content_json: content)

    Reports::Submit.call(membership: @staff, report: report, version: version.reload)

    error = assert_raises(Reports::Review::Denied) do
      Reports::Review.call(
        membership: @reviewer,
        report: report.reload,
        version: report.current_version,
        outcome: "approved"
      )
    end
    assert_match(/independent reviewer/i, error.message)
  end

  test "tampered plaintext fails report artifact integrity check" do
    inspection = submit_inspection!
    report = prepare_and_approve!(inspection)
    version = report.current_version

    original = Storage::SecureDownload.method(:call)
    begin
      Storage::SecureDownload.define_singleton_method(:call) do |**|
        raise "unused"
      end
      # Force mismatch: return foreign bytes while version digest stays approved.
      Storage::SecureDownload.define_singleton_method(:call) do |asset:|
        Struct.new(:plaintext, :content_type, :filename, keyword_init: true).new(
          plaintext: "%PDF-1.4 tampered-h1-bytes",
          content_type: "application/pdf",
          filename: asset.filename
        )
      end

      assert_raises(Reports::SecureDownload::Error) do
        Reports::SecureDownload.call(membership: @staff, version: version)
      end
    ensure
      Storage::SecureDownload.define_singleton_method(:call, original)
    end
  end

  test "revoking release reopens report_release milestone readiness" do
    inspection = submit_inspection!
    report = prepare_and_approve!(inspection)
    version = report.current_version
    release = Reports::Release.call(membership: @staff, report: report, version: version, confirmation: true).release
    milestone = @project.project_milestones.find_by!(kind: "report_release")
    assert milestone.reload.completed?

    Reports::RevokeRelease.call(membership: @staff, release: release, reason: "Withdraw for QA.")
    assert_not milestone.reload.completed?
    assert_not Delivery::TechnicalProgress.project_technically_ready?(@project)
  end

  test "one released report does not make project technically ready while another draft remains" do
    inspection = submit_inspection!
    report = prepare_and_approve!(inspection)
    Reports::Release.call(membership: @staff, report: report, version: report.current_version, confirmation: true)

    second = Reports::Prepare.call(
      membership: @staff,
      project: @project,
      inspection: inspection,
      title: "Second simulated report"
    ).report
    assert second.current_version.draft?
    assert_not Delivery::TechnicalProgress.project_technically_ready?(@project)
  end

  test "approval rolls back when artifact persistence fails" do
    inspection = submit_inspection!
    report = Reports::Prepare.call(membership: @staff, project: @project, inspection: inspection).report
    Reports::UpdateDraft.call(
      membership: @staff,
      report: report,
      version: report.current_version,
      sections: { executive_summary: "Ready" }
    )
    Reports::Submit.call(membership: @staff, report: report, version: report.reload.current_version)

    original = Reports::ArtifactStore.method(:persist_pdf!)
    begin
      Reports::ArtifactStore.define_singleton_method(:persist_pdf!) do |**|
        raise Reports::ArtifactStore::Error, "disk full"
      end
      assert_raises(Reports::Review::InvalidState) do
        Reports::Review.call(
          membership: @reviewer,
          report: report.reload,
          version: report.current_version,
          outcome: "approved"
        )
      end
    ensure
      Reports::ArtifactStore.define_singleton_method(:persist_pdf!, original)
    end

    assert_equal "submitted_for_review", report.reload.current_version.status
    assert_nil report.current_version.artifact_checksum_sha256
  end

  private

    def submit_inspection!
      inspection = Inspections::Create.call(
        membership: @staff,
        project: @project,
        title: "H1 walk",
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

    def prepare_and_approve!(inspection)
      report = Reports::Prepare.call(membership: @staff, project: @project, inspection: inspection).report
      Reports::UpdateDraft.call(
        membership: @staff,
        report: report,
        version: report.current_version,
        sections: { executive_summary: "Simulated H1 summary." }
      )
      Reports::Submit.call(membership: @staff, report: report, version: report.reload.current_version)
      Reports::Review.call(
        membership: @reviewer,
        report: report.reload,
        version: report.current_version,
        outcome: "approved"
      )
      report.reload
    end
end
