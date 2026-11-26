# frozen_string_literal: true

module Delivery
  module TechnicalProgress
    module_function

    def sync!(project:)
      return unless project.is_a?(Project)

      technical = project.project_milestones.find_by(kind: "technical_review")
      if technical&.status == "pending" && inspection_evidence_met?(project)
        technical.update!(status: "completed", completed_at: Time.current, completed_by_membership: nil)
      end

      release = project.project_milestones.find_by(kind: "report_release")
      if release&.status == "pending" && ReportRelease.active.joins(:report).where(reports: { project_id: project.id }).exists?
        release.update!(status: "completed", completed_at: Time.current, completed_by_membership: nil)
      end
    end

    def inspection_evidence_met?(project)
      Inspection.where(project_id: project.id)
                .where(status: %w[submitted corrections_requested completed])
                .exists?
    end

    def report_release_evidence_met?(project)
      ReportRelease.active.joins(:report).where(reports: { project_id: project.id }).exists?
    end
  end
end
