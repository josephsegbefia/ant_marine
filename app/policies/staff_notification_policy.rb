# frozen_string_literal: true

# Staff see and act on their own notifications only.
class StaffNotificationPolicy < ApplicationPolicy
  def index?
    staff?
  end

  def open?
    staff? && record.recipient_membership_id == membership.id
  end

  def mark_all_read?
    staff?
  end

  class Scope < Scope
    def resolve
      return scope.none unless membership&.status == "active" && membership.staff_domain?

      scope.where(recipient_membership_id: membership.id, organization_id: membership.organization_id)
    end
  end

  private

    def staff?
      membership&.status == "active" && membership.staff_domain?
    end
end
