# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if staff_with?("inquiries.view_all") || staff_with?("quotes.view_all") || staff_with?("inquiries.qualify")
        scope.client
      else
        scope.none
      end
    end

    private

      def staff_with?(key)
        membership.staff_domain? &&
          Authorization::EffectivePermissions.allowed?(membership: membership, permission_key: key)
      end
  end

  def index?
    staff_allowed?("inquiries.view_all") || staff_allowed?("quotes.view_all") || manage?
  end

  def show?
    index? && record.client?
  end

  def create?
    manage?
  end

  def new?
    create?
  end

  def update?
    manage? && record.client?
  end

  def edit?
    update?
  end

  def manage_access?
    manage? && staff_allowed?("team.suspend") && record.client?
  end

  def invite?
    manage? && staff_allowed?("team.invite") && record.client?
  end

  def manage?
    staff_allowed?("inquiries.qualify")
  end

  private

    def staff_allowed?(key)
      membership.staff_domain? && allowed?(key)
    end
end
