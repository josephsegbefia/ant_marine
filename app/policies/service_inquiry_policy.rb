# frozen_string_literal: true

class ServiceInquiryPolicy < ApplicationPolicy
  def index?
    staff? && allowed?("inquiries.view_all")
  end

  def show?
    index? && record.organization_id == membership.organization_id
  end

  def prepare_quotation?
    show? && allowed?("quotes.create") && !record.current_status.in?(Commercial::QuoteFromInquiry::CLOSED_STATUSES)
  end

  class Scope < Scope
    def resolve
      return scope.none unless membership&.status == "active" && membership.staff_domain?
      return scope.none unless Authorization::EffectivePermissions.allowed?(membership: membership, permission_key: "inquiries.view_all")

      scope.where(organization_id: membership.organization_id)
    end
  end

  private

    def staff?
      membership&.staff_domain?
    end
end
