# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  def index?
    staff_view_any? || client_view?
  end

  def show?
    view?
  end

  def create?
    staff? && allowed?("projects.create") && Delivery::CreateFromAcceptance.available?
  end

  def new?
    create?
  end

  def update?
    manage?
  end

  # Operational delivery manage (tasks, milestones, schedule, updates).
  # Catalogue projects.manage OR active delivery-scope assignment (P2-OD-042).
  # review / collaborator assignments do not grant manage.
  def manage?
    view? && staff? && Delivery::Access.can_manage_delivery?(membership, record)
  end

  def assign?
    view? && staff? && allowed?("projects.assign")
  end

  def transition?
    manage? && allowed?("projects.manage")
  end

  def view_commercial?
    view? && staff? && (allowed?("quotes.view_all") || allowed?("billing.view_all"))
  end

  def view_internal_notes?
    view? && staff? && (allowed?("projects.manage") || allowed?("projects.view_all") ||
      Delivery::Access.delivery_participant?(membership, record))
  end

  def publish_update?
    manage?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless membership&.status == "active"

      base = scope
      base = base.where.not(mode: "simulated") if Rails.env.production?

      if membership.staff_domain?
        if Authorization::EffectivePermissions.new(membership).allowed?("projects.view_all")
          base.for_operating_organization(membership.organization)
        elsif Authorization::EffectivePermissions.new(membership).allowed?("projects.view_assigned")
          base.for_operating_organization(membership.organization)
               .where(id: Assignment.active.where(user_id: membership.user_id).select(:project_id))
        else
          base.none
        end
      elsif membership.client_domain?
        return base.none unless Authorization::EffectivePermissions.new(membership).allowed?("projects.view_org")

        base.for_client_organization(membership.organization)
      else
        base.none
      end
    end
  end

  private

    def view?
      return false unless membership&.status == "active"
      return false if record.simulated? && Rails.env.production?

      if membership.staff_domain?
        return false unless record.operating_organization_id == membership.organization_id
        return true if allowed?("projects.view_all")
        return true if allowed?("projects.view_assigned") && Delivery::Access.assigned_any_scope?(membership, record)

        false
      elsif membership.client_domain?
        allowed?("projects.view_org") && record.client_organization_id == membership.organization_id
      else
        false
      end
    end

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
