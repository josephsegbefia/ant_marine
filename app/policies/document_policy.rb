# frozen_string_literal: true

class DocumentPolicy < ApplicationPolicy
  def index?
    staff_view_any? || client_view?
  end

  def show?
    Documents::Access.can_view_metadata?(membership, record)
  end

  def create?
    project = record.is_a?(Project) ? record : record.try(:project)
    return false unless project

    Documents::Access.can_upload?(membership, project)
  end

  def update?
    staff? && allowed?("documents.manage") && show?
  end

  def upload?
    Documents::Access.can_upload?(membership, record.project)
  end

  def submit_for_review?
    staff? && Documents::Access.can_upload?(membership, record.project) && show?
  end

  def review?
    Documents::Access.can_review?(membership, record)
  end

  def release?
    Documents::Access.can_release?(membership, record)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless membership&.status == "active"

      base = scope
      base = base.joins(:project).where.not(projects: { mode: "simulated" }) if Rails.env.production?

      if membership.staff_domain?
        if Authorization::EffectivePermissions.new(membership).allowed?("projects.view_all")
          base.where(operating_organization_id: membership.organization_id)
        elsif Authorization::EffectivePermissions.new(membership).allowed?("projects.view_assigned")
          assigned_project_ids = Assignment.active.where(user_id: membership.user_id).select(:project_id)
          # Broad project filter only — controllers further narrow with
          # Documents::Access.visible_documents_for_project so collaborators
          # do not see unauthorized titles.
          base.where(operating_organization_id: membership.organization_id)
               .where(project_id: assigned_project_ids)
        else
          base.none
        end
      elsif membership.client_domain?
        return base.none unless Authorization::EffectivePermissions.new(membership).allowed?("projects.view_org")

        released_ids = DocumentRelease.active.where(client_organization_id: membership.organization_id).select(:document_id)
        base.where(client_organization_id: membership.organization_id)
            .where(visibility_intent: "client_submitted")
            .or(base.where(client_organization_id: membership.organization_id).where(id: released_ids))
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
