class Membership < ApplicationRecord
  STATUSES = %w[invited active suspended removed].freeze
  PORTAL_ACCESS_STATUSES = %w[active].freeze

  belongs_to :user
  belongs_to :organization

  validates :role_key, inclusion: { in: RoleKeys::ALL }
  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :organization_id }

  validate :role_matches_organization_kind

  scope :portal_eligible, -> { where(status: PORTAL_ACCESS_STATUSES) }
  scope :active, -> { where(status: "active") }

  def staff_domain?
    organization.ant_marine?
  end

  def client_domain?
    organization.client?
  end

  def portal_access?
    PORTAL_ACCESS_STATUSES.include?(status)
  end

  private

    def role_matches_organization_kind
      return if role_key.blank? || organization.nil?

      if organization.ant_marine? && !RoleKeys.staff?(role_key)
        errors.add(:role_key, "must be a staff role for ANT Marine membership")
      elsif organization.client? && !RoleKeys.client?(role_key)
        errors.add(:role_key, "must be a client role for client organisation membership")
      end
    end
end
