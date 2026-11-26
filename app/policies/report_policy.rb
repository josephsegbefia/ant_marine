# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  def index?
    staff_view_any? || client_view?
  end

  def show?
    Reports::Access.can_view_metadata?(membership, record)
  end

  def create?
    project = record.is_a?(Project) ? record : record.project
    return false unless project

    Reports::Access.can_draft?(membership, record.is_a?(Report) ? record : Report.new(project: project))
  end

  def update?
    Reports::Access.can_draft?(membership, record)
  end

  def review?
    Reports::Access.can_review?(membership, record)
  end

  def release?
    Reports::Access.can_release?(membership, record)
  end

  def submit?
    Reports::Access.can_draft?(membership, record)
  end

  def revise?
    return false unless Reports::Access.can_draft?(membership, record)

    version = record.current_version
    version.present? && %w[changes_requested approved].include?(version.status) &&
      !record.report_versions.exists?(status: "draft")
  end

  def download?
    version = record.current_version
    return false unless version&.approved?

    ReportVersionPolicy.new(membership, version).download?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless membership&.status == "active"

      base = scope
      base = base.joins(:project).where.not(projects: { mode: "simulated" }) if Rails.env.production?

      if membership.staff_domain?
        perms = Authorization::EffectivePermissions.new(membership)
        if perms.allowed?("projects.view_all")
          base.where(operating_organization_id: membership.organization_id)
        elsif perms.allowed?("projects.view_assigned")
          assigned_project_ids = Assignment.active.where(user_id: membership.user_id).select(:project_id)
          base.where(operating_organization_id: membership.organization_id)
               .where(project_id: assigned_project_ids)
        else
          base.none
        end
      elsif membership.client_domain?
        return base.none unless Authorization::EffectivePermissions.new(membership).allowed?("projects.view_org")

        released_ids = ReportRelease.active.where(client_organization_id: membership.organization_id).select(:report_id)
        base.where(client_organization_id: membership.organization_id).where(id: released_ids)
      else
        base.none
      end
    end
  end

  private

    def staff_view_any?
      staff? && (allowed?("projects.view_all") || allowed?("projects.view_assigned"))
    end

    def client_view?
      membership&.client_domain? && allowed?("projects.view_org")
    end

    def staff?
      membership&.staff_domain?
    end
end
