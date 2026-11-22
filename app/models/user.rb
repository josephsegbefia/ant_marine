class User < ApplicationRecord
  STATUSES = %w[active suspended].freeze

  has_secure_password

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_digest&.last(10)
  end

  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :status, inclusion: { in: STATUSES }

  after_update :bump_security_version_on_password_change, if: :saved_change_to_password_digest?

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def suspend!
    transaction do
      update!(status: "suspended")
      increment!(:security_version)
      sessions.where(revoked_at: nil).find_each(&:revoke!)
    end
  end

  def portal_eligible_memberships
    memberships.portal_eligible.includes(:organization)
  end

  def staff_memberships
    portal_eligible_memberships.joins(:organization).where(organizations: { kind: "ant_marine" })
  end

  def client_memberships
    portal_eligible_memberships.joins(:organization).where(organizations: { kind: "client" })
  end

  private

    def bump_security_version_on_password_change
      increment!(:security_version)
      sessions.where(revoked_at: nil).find_each(&:revoke!)
    end
end
