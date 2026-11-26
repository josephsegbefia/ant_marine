# frozen_string_literal: true

class InspectionTemplatePolicy < ApplicationPolicy
  def index?
    manage_catalogue?
  end

  def show?
    manage_catalogue? &&
      record.operating_organization_id == membership.organization_id
  end

  def create?
    manage_catalogue?
  end

  def update?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless membership&.status == "active" && membership.staff_domain?
      return scope.none unless Inspections::Access.can_manage_templates?(membership)

      scope.where(operating_organization_id: membership.organization_id)
    end
  end

  private

    def manage_catalogue?
      membership&.staff_domain? && Inspections::Access.can_manage_templates?(membership)
    end
end
