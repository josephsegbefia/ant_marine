# frozen_string_literal: true

class InspectionPolicy < ApplicationPolicy
  def index?
    staff_view_any? || client_view?
  end

  def show?
    Inspections::Access.can_view?(membership, record)
  end

  def create?
    project = record.is_a?(Project) ? record : record.project
    return false unless project

    Inspections::Access.can_list_project_inspections?(membership, project) &&
      membership.staff_domain? &&
      allowed?("projects.manage")
  end

  def update?
    Inspections::Access.can_edit_checklist?(membership, record)
  end

  def submit?
    Inspections::Access.can_edit_checklist?(membership, record)
  end

  def request_corrections?
    Inspections::Access.can_coordinate?(membership, record)
  end

  def complete?
    Inspections::Access.can_coordinate?(membership, record)
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

        base.where(client_organization_id: membership.organization_id)
            .where.not(status: %w[draft cancelled])
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
