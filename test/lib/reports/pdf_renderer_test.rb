# frozen_string_literal: true

require "test_helper"

class Reports::PdfRendererTest < ActiveSupport::TestCase
  def pdf_text(data)
    data.b.scan(/\[(.*?)\]\s*TJ|<([0-9a-fA-F]+)>\s*Tj/m).map do |array, single|
      chunks = array ? array.scan(/<([0-9a-fA-F]+)>/).flatten : [ single ]
      chunks.map { |hex| [ hex ].pack("H*").force_encoding("Windows-1252").encode("UTF-8") }.join
    end.join("\n")
  end

  test "renders simulated watermark and findings" do
    staff = memberships(:ops_manager_membership)
    project = build_accepted_project!(staff: staff)[:project]
    inspection = build_inspection!(project: project, staff: staff, status: "submitted")
    report = build_report!(project: project, staff: staff, inspection: inspection)
    version = report.report_versions.create!(
      version_number: 1,
      status: "draft",
      title: report.title,
      content_json: {
        "sections" => { "executive_summary" => "Test" },
        "findings" => [ { "reference_number" => "F-001", "title" => "Note", "observation" => "Seen gap" } ],
        "inspection" => { "reference_number" => inspection.reference_number, "title" => inspection.title }
      },
      authored_by_membership: staff
    )
    text = pdf_text(Reports::PdfRenderer.render(report: report, version: version))
    assert_includes text, "SIMULATED"
    assert_includes text, "F-001"
  end
end
