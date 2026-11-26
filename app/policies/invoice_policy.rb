# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def index?
    staff_billing_view? || client_billing_view?
  end

  def show?
    Billing::Access.can_view_metadata?(membership, record)
  end

  def create?
    Billing::Access.can_manage?(membership) && Billing::CreateDraft.available?
  end

  def new?
    create?
  end

  def update?
    Billing::Access.can_manage?(membership, record) && record.draft?
  end

  def issue?
    Billing::Access.can_issue?(membership, record)
  end

  def release?
    Billing::Access.can_release?(membership, record)
  end

  def revoke_release?
    release?
  end

  def record_payment?
    Billing::Access.can_record_payment?(membership, record)
  end

  def reverse_payment?
    Billing::Access.can_adjust?(membership, record)
  end

  def void?
    Billing::Access.can_adjust?(membership, record) && record.issued?
  end

  def download?
    Billing::Access.can_download?(membership, record)
  end

  def finance_dashboard?
    staff_billing_view?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless membership&.status == "active"

      if membership.staff_domain?
        base = scope.for_operating_organization(membership.organization)
        base = base.where.not(mode: "simulated") if Rails.env.production?
        perms = Authorization::EffectivePermissions.new(membership)
        return base if perms.allowed?("billing.view_all")
        return base.none unless perms.allowed?("billing.view")

        project_ids = Project.for_operating_organization(membership.organization).select do |project|
          Billing::Access.project_visible?(membership, project)
        end.map(&:id)
        base.where(project_id: project_ids)
      elsif membership.client_domain?
        return scope.none unless Authorization::EffectivePermissions.new(membership).allowed?("billing.view")

        scope.for_client_organization(membership.organization)
             .issued
             .where(id: InvoiceRelease.active.select(:invoice_id))
      else
        scope.none
      end
    end
  end

  private

    def staff_billing_view?
      membership&.staff_domain? &&
        (allowed?("billing.view_all") || allowed?("billing.view"))
    end

    def client_billing_view?
      membership&.client_domain? && allowed?("billing.view")
    end
end
