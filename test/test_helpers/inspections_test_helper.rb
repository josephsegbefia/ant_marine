# frozen_string_literal: true

module InspectionsTestHelper
  def seed_qa_template!(staff: memberships(:ops_manager_membership), org: organizations(:ant_marine))
    Inspections::QaTemplateSeeder.seed!(
      operating_organization: org,
      created_by_membership: staff
    )
  end

  def build_inspection!(project:, staff:, assignee: nil, status: "assigned")
    template = seed_qa_template!(staff: staff, org: project.operating_organization)
    Inspection.create!(
      reference_number: "INSP-#{SecureRandom.hex(4).upcase}",
      operating_organization: project.operating_organization,
      client_organization: project.client_organization,
      project: project,
      inspection_template_version: template.current_version,
      title: "Simulated vessel observation",
      inspection_type: "general_observation",
      status: status,
      created_by_membership: staff,
      assigned_surveyor_membership: assignee || staff
    )
  end

  def build_report!(project:, staff:, inspection: nil)
    Report.create!(
      reference_number: "RPT-#{SecureRandom.hex(4).upcase}",
      operating_organization: project.operating_organization,
      client_organization: project.client_organization,
      project: project,
      inspection: inspection,
      title: "Simulated technical report",
      created_by_membership: staff
    )
  end
end

ActiveSupport::TestCase.include(InspectionsTestHelper)
