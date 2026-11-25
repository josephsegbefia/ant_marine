# frozen_string_literal: true

class QuoteResponsePolicy < ApplicationPolicy
  def create?
    return false unless Commercial::QuoteDecision.available?
    return false unless membership&.client_domain? && membership.portal_access?
    return false unless record.is_a?(QuotePortalRelease) && record.active?
    return false unless record.client_organization_id == membership.organization_id
    return false unless record.simulated?

    allowed?("quotes.accept") || allowed?("quotes.decline")
  end

  def accept?
    create? && allowed?("quotes.accept")
  end

  def decline?
    create? && allowed?("quotes.decline")
  end

  def request_changes?
    create? && allowed?("quotes.accept")
  end

  def show?
    return false unless membership&.portal_access?

    if membership.client_domain?
      record.client_organization_id == membership.organization_id &&
        (allowed?("quotes.view_org") || allowed?("quotes.accept") || allowed?("quotes.decline"))
    else
      membership.staff_domain? && allowed?("quotes.view_all")
    end
  end
end
