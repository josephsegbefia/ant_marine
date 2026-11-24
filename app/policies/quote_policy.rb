# frozen_string_literal: true

class QuotePolicy < ApplicationPolicy
  def index?
    allowed?("quotes.view_all")
  end

  def show?
    view?
  end

  def create?
    allowed?("quotes.create")
  end

  def new?
    create?
  end

  def update?
    manage_draft?
  end

  def submit_for_review?
    manage_draft? && record.status == "draft"
  end

  def return_for_correction?
    allowed?("quotes.approve") && record.status == "pending_review"
  end

  def approve?
    allowed?("quotes.approve") && record.status == "pending_review"
  end

  def issue?
    allowed?("quotes.send") && record.status == "approved_for_issuance"
  end

  def withdraw?
    allowed?("quotes.withdraw") && record.status.in?(%w[draft pending_review approved_for_issuance issued])
  end

  def pdf?
    view?
  end

  class Scope < Scope
    def resolve
      return scope.none unless membership&.staff_domain?
      return scope.none unless Authorization::EffectivePermissions.allowed?(membership: membership, permission_key: "quotes.view_all")

      scope.where(organization_id: membership.organization_id)
    end
  end

  private

    def view?
      allowed?("quotes.view_all") && record.organization_id == membership.organization_id
    end

    def manage_draft?
      allowed?("quotes.create") && view? && record.editable?
    end
end
