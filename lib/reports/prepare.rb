# frozen_string_literal: true

module Reports
  class Prepare
    Result = Data.define(:report, :version)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.available?
      !Rails.env.production?
    end

    def self.call(membership:, project:, inspection:, title: nil)
      new(membership: membership).call(project: project, inspection: inspection, title: title)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(project:, inspection:, title:)
      raise Denied, "Simulated report preparation is not available in production yet." unless self.class.available?
      raise Denied, "You are not allowed to draft a report for this project." unless Reports::Access.can_draft?(@membership, Report.new(project: project))
      raise InvalidState, "Only simulated projects can receive development reports." unless project.simulated?
      raise InvalidState, "That inspection does not belong to this project." unless inspection.project_id == project.id
      raise InvalidState, "Complete or submit the inspection before preparing a report." unless inspection.submitted_or_later?

      snapshot = build_snapshot(inspection)
      report_title = title.to_s.strip.presence || "Technical report — #{inspection.title}"

      report = nil
      version = nil
      Report.transaction do
        report = Report.create!(
          reference_number: Reports::Reference.generate!,
          operating_organization: project.operating_organization,
          client_organization: project.client_organization,
          project: project,
          inspection: inspection,
          title: report_title,
          report_kind: "technical_report",
          mode: "simulated",
          created_by_membership: @membership
        )
        version = report.report_versions.create!(
          version_number: 1,
          status: "draft",
          title: report_title,
          content_json: snapshot,
          authored_by_membership: @membership
        )
        report.update!(current_version_id: version.id)
        audit = Reports::Audit.prepared(report: report, version: version, actor_membership: @membership)
        report
      end

      Result.new(report: report, version: version)
    end

    private

      def build_snapshot(inspection)
        findings = inspection.inspection_findings.where(status: %w[recorded included_in_report]).order(:id).map do |finding|
          {
            "reference_number" => finding.reference_number,
            "title" => finding.title,
            "observation" => finding.observation,
            "recommendation" => finding.recommendation,
            "classification" => finding.classification,
            "location_or_equipment" => finding.location_or_equipment
          }
        end

        evidence = inspection.inspection_evidence_links.includes(document_version: :document).order(:id).map do |link|
          version = link.document_version
          {
            "document_version_id" => version.id,
            "document_title" => version.document.title,
            "filename" => version.filename,
            "checksum_sha256" => version.checksum_sha256,
            "checklist_item_key" => link.checklist_item_key,
            "finding_id" => link.finding_id
          }
        end

        {
          "disclaimer" => Inspections::QaTemplateSeeder::DISCLAIMER,
          "inspection" => {
            "id" => inspection.id,
            "reference_number" => inspection.reference_number,
            "title" => inspection.title,
            "inspection_type" => inspection.inspection_type,
            "submitted_at" => inspection.submitted_at&.iso8601
          },
          "findings" => findings,
          "evidence" => evidence,
          "sections" => {
            "executive_summary" => "",
            "conclusions" => "",
            "limitations" => "This report was generated from simulated inspection data for development and training only."
          }
        }
      end
  end
end
