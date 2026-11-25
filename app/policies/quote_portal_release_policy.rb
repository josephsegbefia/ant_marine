# frozen_string_literal: true

class QuotePortalReleasePolicy < ApplicationPolicy
  def index?
    client_view? || staff_release?
  end

  def show?
    return false unless record.active?

    if membership.client_domain?
      client_view? && record.client_organization_id == membership.organization_id
    else
      staff_release?
    end
  end

  def pdf?
    show? && (membership.client_domain? ? allowed?("quotes.view_org") : staff_release?)
  end

  def create?
    staff_release?
  end

  class Scope < Scope
    def resolve
      return scope.none unless membership&.status == "active"

      if membership.client_domain? && Authorization::EffectivePermissions.allowed?(membership: membership, permission_key: "quotes.view_org")
        scope.active.for_client_organization(membership.organization)
      elsif membership.staff_domain? && Authorization::EffectivePermissions.allowed?(membership: membership, permission_key: "quotes.send")
        scope.all
      else
        scope.none
      end
    end
  end

  private

    def client_view?
      membership&.status == "active" && membership.client_domain? && allowed?("quotes.view_org")
    end

    def staff_release?
      membership&.status == "active" && membership.staff_domain? && allowed?("quotes.send")
    end
end
