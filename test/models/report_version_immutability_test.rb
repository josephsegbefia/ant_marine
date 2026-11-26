# frozen_string_literal: true

require "test_helper"

class ReportVersionImmutabilityTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  test "sql mutation of approved report content is rejected" do
    version = approve_report!.current_version
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "UPDATE report_versions SET content_json = '{}'::jsonb WHERE id = #{version.id}"
      )
    end
  end

  test "sql replacement of approved artifact is rejected" do
    version = approve_report!.current_version
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "UPDATE report_versions SET artifact_checksum_sha256 = '#{'a' * 64}' WHERE id = #{version.id}"
      )
    end
  end

  test "sql delete of report version is rejected" do
    version = approve_report!.current_version
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute("DELETE FROM report_versions WHERE id = #{version.id}")
    end
  end

  test "sql delete of report release is rejected" do
    report = approve_report!
    release = Reports::Release.call(
      membership: @staff,
      report: report,
      version: report.current_version,
      confirmation: true
    ).release
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute("DELETE FROM report_releases WHERE id = #{release.id}")
    end
  end

  private

    def approve_report!
      inspection = Inspections::Create.call(
        membership: @staff,
        project: @project,
        title: "History protect walk",
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
      Inspections::Submit.call(membership: @surveyor, inspection: inspection.reload, confirmation: true)

      report = Reports::Prepare.call(membership: @staff, project: @project, inspection: inspection.reload).report
      Reports::UpdateDraft.call(
        membership: @staff,
        report: report,
        version: report.current_version,
        sections: { executive_summary: "Simulated summary" }
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
