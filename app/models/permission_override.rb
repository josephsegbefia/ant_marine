# frozen_string_literal: true

class PermissionOverride < ApplicationRecord
  EFFECTS = %w[allow deny].freeze

  belongs_to :membership
  belongs_to :permission
  belongs_to :granted_by_membership, class_name: "Membership"

  validates :effect, inclusion: { in: EFFECTS }
  validates :permission_id, uniqueness: { scope: :membership_id }
  validate :memberships_share_organization
  validate :permission_applicable_to_membership

  def allow?
    effect == "allow"
  end

  def deny?
    effect == "deny"
  end

  private

    def memberships_share_organization
      return if membership.nil? || granted_by_membership.nil?

      errors.add(:granted_by_membership, "must belong to the same organisation") if
        membership.organization_id != granted_by_membership.organization_id
    end

    def permission_applicable_to_membership
      return if permission.nil? || membership.nil?

      if membership.staff_domain? && !permission.staff_applicable?
        errors.add(:permission, "is not applicable to staff memberships")
      elsif membership.client_domain? && !permission.client_applicable?
        errors.add(:permission, "is not applicable to client memberships")
      end
    end
end
