# frozen_string_literal: true

class Invitation < ApplicationRecord
  STATUSES = %w[pending accepted revoked expired].freeze
  DEFAULT_EXPIRY = 7.days

  belongs_to :organization
  belongs_to :invited_by_membership, class_name: "Membership"
  belongs_to :accepted_by_user, class_name: "User", optional: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role_key, inclusion: { in: RoleKeys::ALL }
  validates :status, inclusion: { in: STATUSES }
  validates :token_digest, presence: true
  validates :expires_at, presence: true

  validate :role_matches_organization_kind

  scope :pending, -> { where(status: "pending") }
  scope :usable, -> { pending.where("expires_at > ?", Time.current) }

  class InvalidToken < StandardError; end

  class UnusableInvitation < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason)
    end
  end

  def self.find_by_token!(raw_token)
    digest = Invitations::Token.digest(raw_token)
    invitation = find_by(token_digest: digest)
    raise InvalidToken, "invalid" unless invitation

    invitation.resolve_lifecycle!
    raise UnusableInvitation.new(invitation.public_state), invitation.public_state unless invitation.usable?

    invitation
  end

  def usable?
    status == "pending" && !expired?
  end

  def expired?
    expires_at <= Time.current
  end

  def public_state
    return "expired" if status == "expired" || (status == "pending" && expired?)
    return status unless status == "pending"

    "pending"
  end

  def resolve_lifecycle!
    return unless status == "pending" && expired?

    update!(status: "expired")
  end

  def revoke!
    return unless status == "pending"

    update!(status: "revoked")
  end

  def staff_target?
    RoleKeys.staff?(role_key)
  end

  def client_target?
    RoleKeys.client?(role_key)
  end

  private

    def role_matches_organization_kind
      return if role_key.blank? || organization.nil?

      if organization.ant_marine? && !RoleKeys.staff?(role_key)
        errors.add(:role_key, "must be a staff role for ANT Marine invitations")
      elsif organization.client? && !RoleKeys.client?(role_key)
        errors.add(:role_key, "must be a client role for client organisation invitations")
      end
    end
end
