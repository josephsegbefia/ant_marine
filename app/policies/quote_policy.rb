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

  def edit?
    view?
  end

  def update?
    manage_draft?
  end

  def submit_for_review?
    manage_draft?
  end

  def return_for_correction?
    review?
  end

  def approve?
    review? && independent_reviewer?
  end

  def review?
    view? && allowed?("quotes.approve") && record.status == "pending_review"
  end

  def another_reviewer_required?
    review? && !independent_reviewer?
  end

  def issue?
    Commercial::QuoteIssuance.available? && view? && allowed?("quotes.send") &&
      record.status == "approved_for_issuance"
  end

  def withdraw?
    view? && allowed?("quotes.withdraw") &&
      record.status.in?(%w[draft pending_review returned_for_correction approved_for_issuance issued])
  end

  def pdf?
    view?
  end

  def version?
    view?
  end

  def send_quotation?
    view? && allowed?("quotes.send")
  end

  def issuance?
    send_quotation? && (record.status == "approved_for_issuance" || record.quote_deliveries.exists?)
  end

  def create_revision?
    allowed?("quotes.create") && view? &&
      record.status.in?(Commercial::QuoteRevisionCreator::SOURCE_STATUSES) &&
      record.current_revision&.version_frozen? == true &&
      !QuoteDelivery.in_flight_for?(record.current_revision)
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

    def independent_reviewer?
      revision = record.current_revision
      revision.present? && revision.attribution_recorded? && !revision.prepared_or_edited_by?(membership)
    end
end
