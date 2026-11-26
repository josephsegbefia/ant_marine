# frozen_string_literal: true

require "test_helper"

class InspectionDomainTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
    @template = seed_qa_template!(staff: @staff, org: @project.operating_organization)
  end

  test "inspection rejects organisation mismatch with project" do
    inspection = Inspection.new(
      reference_number: "INSP-BAD",
      operating_organization: @project.operating_organization,
      client_organization: organizations(:other_client),
      project: @project,
      inspection_template_version: @template.current_version,
      title: "Bad org",
      inspection_type: "general",
      created_by_membership: @staff
    )
    assert_not inspection.valid?
    assert inspection.errors[:client_organization].any?
  end

  test "template version rejects invalid schema_json" do
    version = InspectionTemplateVersion.new(
      inspection_template: @template,
      version_number: 99,
      schema_json: { "sections" => [] },
      created_by_membership: @staff
    )
    assert_not version.valid?
    assert version.errors[:schema_json].any?
  end

  test "report rejects inspection from another project" do
    other = build_accepted_project!(staff: @staff, idempotency_key: "other-#{SecureRandom.hex(4)}")[:project]
    inspection = build_inspection!(project: other, staff: @staff)
    report = Report.new(
      reference_number: "RPT-BAD",
      operating_organization: @project.operating_organization,
      client_organization: @project.client_organization,
      project: @project,
      inspection: inspection,
      title: "Mismatched",
      created_by_membership: @staff
    )
    assert_not report.valid?
    assert report.errors[:inspection].any?
  end

  test "qa template is clearly labelled simulated" do
    assert_includes @template.title, "SIMULATED QA"
    assert_includes @template.description, "not a regulatory"
  end
end
