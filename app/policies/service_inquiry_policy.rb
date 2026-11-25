# frozen_string_literal: true

# Staff holding inquiries.view_all see every enquiry in their organisation; staff holding
# only inquiries.view_assigned see the enquiries assigned to them. Triage and assignment
# need inquiries.qualify. Services re-check these rules inside their transactions.
class ServiceInquiryPolicy < ApplicationPolicy
  def index?
    staff? && (view_all? || allowed?("inquiries.view_assigned"))
  end

  def show?
    return false unless staff? && record.organization_id == membership.organization_id

    view_all? || (assigned_to_me? && allowed?("inquiries.view_assigned"))
  end

  def triage?
    show? && allowed?("inquiries.qualify")
  end

  def assign?
    triage?
  end

  def note?
    show? && (allowed?("inquiries.qualify") || (assigned_to_me? && allowed?("inquiries.view_assigned")))
  end

  def prepare_quotation?
    show? && view_all? && allowed?("quotes.create") && !record.current_status.in?(Commercial::QuoteFromInquiry::CLOSED_STATUSES)
  end

  class Scope < Scope
    def resolve
      return scope.none unless membership&.status == "active" && membership.staff_domain?

      permissions = Authorization::EffectivePermissions.new(membership)
      in_org = scope.where(organization_id: membership.organization_id)
      return in_org if permissions.allowed?("inquiries.view_all")
      return in_org.where(assigned_membership_id: membership.id) if permissions.allowed?("inquiries.view_assigned")

      scope.none
    end
  end

  private

    def staff?
      membership&.status == "active" && membership.staff_domain?
    end

    def view_all?
      allowed?("inquiries.view_all")
    end

    def assigned_to_me?
      record.respond_to?(:assigned_membership_id) && record.assigned_membership_id.present? &&
        record.assigned_membership_id == membership&.id
    end
end
