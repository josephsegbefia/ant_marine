class Session < ApplicationRecord
  ABSOLUTE_TIMEOUT = 30.days
  IDLE_TIMEOUT = 12.hours

  belongs_to :user
  belongs_to :membership, optional: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def usable?
    return false if revoked_at.present?
    return false if Time.current > expires_at
    return false if idle_expired?
    return false unless user.active?
    user.security_version == security_version_at_issue
  end

  def touch_activity!
    return if idle_expired?

    update_column(:last_active_at, Time.current)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def idle_expired?
    last_active_at < IDLE_TIMEOUT.ago
  end

  def sync_permission_epoch_from!(membership)
    update!(permission_epoch_at_issue: membership&.permission_epoch || 0)
  end

  def permission_epoch_stale?(membership)
    return false unless membership

    permission_epoch_at_issue != membership.permission_epoch
  end

  def self.issue_for!(user:, ip_address:, user_agent:, membership: nil)
    now = Time.current
    create!(
      user: user,
      membership: membership,
      ip_address: ip_address,
      user_agent: user_agent,
      security_version_at_issue: user.security_version,
      permission_epoch_at_issue: membership&.permission_epoch || 0,
      expires_at: now + ABSOLUTE_TIMEOUT,
      last_active_at: now
    )
  end
end
