# frozen_string_literal: true

module Reports
  # F4-07 technical report access — separate from document release.
  module Access
    module_function

    def can_list_project_reports?(membership, project)
      return false unless membership&.status == "active" && project.is_a?(Project)
      return false if project.simulated? && Rails.env.production?

      if membership.staff_domain?
        staff_project_visible?(membership, project)
      elsif membership.client_domain?
        client_project_visible?(membership, project)
      else
        false
      end
    end

    def visible_reports_for_project(membership, project)
      base = Report.where(project_id: project.id)
      return Report.none unless can_list_project_reports?(membership, project)

      if membership.staff_domain?
        return base if effective(membership).allowed?("projects.view_all")
        return base if delivery_participant?(membership, project)

        scope = assignment_scope(membership, project)
        case scope
        when "review"
          base.joins(:report_versions).where.not(report_versions: { status: "draft" }).distinct
        when "delivery"
          base
        else
          Report.none
        end
      elsif membership.client_domain?
        released_ids = ReportRelease.active.where(client_organization_id: membership.organization_id).select(:report_id)
        base.where(id: released_ids)
      else
        Report.none
      end
    end

    def can_view_metadata?(membership, report)
      return false unless membership&.status == "active" && report.is_a?(Report)
      return false if report.project.simulated? && Rails.env.production?

      project = report.project
      if membership.staff_domain?
        return false unless project.operating_organization_id == membership.organization_id
        return true if effective(membership).allowed?("projects.view_all")
        return false unless assigned_any_scope?(membership, project)

        scope = assignment_scope(membership, project)
        return true if scope == "delivery"
        return true if scope == "review" && effective(membership).allowed?("reports.review")
        return true if effective(membership).allowed?("reports.view_draft_staff")

        false
      elsif membership.client_domain?
        return false unless client_project_visible?(membership, project)

        report.report_releases.active.exists?(client_organization_id: membership.organization_id)
      else
        false
      end
    end

    def can_view_draft?(membership, report)
      return false unless membership&.staff_domain?
      return false unless can_view_metadata?(membership, report)

      effective(membership).allowed?("reports.view_draft_staff") ||
        effective(membership).allowed?("reports.draft") ||
        effective(membership).allowed?("projects.view_all")
    end

    def can_draft?(membership, report)
      return false unless membership&.staff_domain?
      return false unless can_view_metadata?(membership, report)
      return false unless report.project.operating_organization_id == membership.organization_id

      effective(membership).allowed?("reports.draft") ||
        effective(membership).allowed?("projects.manage") ||
        (delivery_participant?(membership, report.project) && effective(membership).allowed?("projects.view_assigned"))
    end

    def can_review?(membership, report)
      return false unless membership&.staff_domain?
      return false unless can_view_metadata?(membership, report)

      scope = assignment_scope(membership, report.project)
      (scope == "review" || effective(membership).allowed?("projects.view_all")) &&
        effective(membership).allowed?("reports.review")
    end

    def can_release?(membership, report)
      return false unless membership&.staff_domain?
      return false unless report.project.operating_organization_id == membership.organization_id

      effective(membership).allowed?("reports.release") ||
        (delivery_participant?(membership, report.project) && effective(membership).allowed?("projects.manage"))
    end

    def can_download_release?(membership, release)
      return false unless membership&.status == "active" && release.is_a?(ReportRelease)
      return false unless release.active?

      report = release.report
      if membership.staff_domain?
        can_view_metadata?(membership, report) &&
          report.project.operating_organization_id == membership.organization_id
      elsif membership.client_domain?
        release.client_organization_id == membership.organization_id &&
          client_project_visible?(membership, report.project)
      else
        false
      end
    end

    def delivery_participant?(membership, project)
      Delivery::Access.delivery_participant?(membership, project)
    end

    def assigned_any_scope?(membership, project)
      Delivery::Access.assigned_any_scope?(membership, project)
    end

    def effective(membership)
      Authorization::EffectivePermissions.new(membership)
    end

    def staff_project_visible?(membership, project)
      return false unless project.operating_organization_id == membership.organization_id
      return true if effective(membership).allowed?("projects.view_all")
      return true if effective(membership).allowed?("projects.view_assigned") && assigned_any_scope?(membership, project)

      false
    end

    def client_project_visible?(membership, project)
      effective(membership).allowed?("projects.view_org") &&
        project.client_organization_id == membership.organization_id
    end

    def assignment_scope(membership, project)
      return "delivery" if project.coordinator_membership_id == membership.id

      assignment = project.active_assignment_for(membership.user)
      assignment&.access_scope
    end
  end
end
