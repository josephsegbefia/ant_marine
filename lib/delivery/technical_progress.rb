# frozen_string_literal: true

module Delivery
  # Conservative technical milestone evidence for F4-07.
  # Milestone kinds use an "at least one" evidence gate until an explicit
  # required-deliverable catalogue exists. Project-level readiness remains
  # stricter and is never automatic commercial closure.
  module TechnicalProgress
    module_function

    def sync!(project:)
      return unless project.is_a?(Project)

      technical = project.project_milestones.find_by(kind: "technical_review")
      if technical
        if technical.status == "pending" && inspection_evidence_met?(project)
          technical.update!(status: "completed", completed_at: Time.current, completed_by_membership: nil)
        elsif technical.status == "completed" && !inspection_evidence_met?(project)
          reopen_milestone!(technical)
        end
      end

      release = project.project_milestones.find_by(kind: "report_release")
      if release
        if release.status == "pending" && report_release_evidence_met?(project)
          release.update!(status: "completed", completed_at: Time.current, completed_by_membership: nil)
        elsif release.status == "completed" && !report_release_evidence_met?(project)
          reopen_milestone!(release)
        end
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

    # Project-level technical readiness — not invoice or project closure.
    # Incomplete while draft/in-progress inspections remain, while reports
    # await review/approval/release, or while no active report release exists
    # after technical work has started. Multiple required deliverables are not
    # yet modelled; one released report does not imply whole-project delivery.
    def project_technically_ready?(project)
      return false unless project.is_a?(Project)
      return false unless inspection_evidence_met?(project)
      return false unless report_release_evidence_met?(project)

      open_inspections = Inspection.where(project_id: project.id)
                                   .where(status: %w[draft assigned in_progress corrections_requested])
                                   .exists?
      return false if open_inspections

      unfinished_reports = ReportVersion.joins(:report)
                                        .where(reports: { project_id: project.id })
                                        .where(status: %w[draft submitted_for_review changes_requested])
                                        .exists?
      return false if unfinished_reports

      true
    end

    def reopen_milestone!(milestone)
      milestone.update!(status: "pending", completed_at: nil, completed_by_membership: nil)
    end
    private_class_method :reopen_milestone!
  end
end
