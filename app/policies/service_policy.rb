# frozen_string_literal: true

class ServicePolicy < ApplicationPolicy
  def index?
    staff_content_access?
  end

  def show?
    staff_content_access?
  end

  def create?
    allowed?("content.manage")
  end

  def update?
    allowed?("content.manage") && same_ant_marine_org?
  end

  def submit_for_review?
    allowed?("content.manage") && same_ant_marine_org?
  end

  def withdraw?
    allowed?("content.manage") && same_ant_marine_org?
  end

  def approve?
    allowed?("content.publish") && same_ant_marine_org?
  end

  def publish?
    allowed?("content.publish") && same_ant_marine_org?
  end

  def unpublish?
    allowed?("content.publish") && same_ant_marine_org?
  end

  def archive?
    allowed?("content.publish") && same_ant_marine_org?
  end

  class Scope < Scope
    def resolve
      return scope.none unless membership&.organization&.ant_marine?

      scope.where(organization_id: membership.organization_id)
    end
  end

  private

    def staff_content_access?
      membership&.staff_domain? && (
        allowed?("content.view_draft") ||
        allowed?("content.manage") ||
        allowed?("content.publish")
      )
    end

    def same_ant_marine_org?
      membership&.organization_id == record.organization_id &&
        membership.organization.ant_marine?
    end
end
