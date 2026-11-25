# frozen_string_literal: true

class ClientContact < ApplicationRecord
  STATUSES = %w[active archived].freeze

  belongs_to :organization
  belongs_to :created_by_membership, class_name: "Membership", optional: true

  validates :full_name, presence: true, length: { maximum: 120 }
  validates :status, inclusion: { in: STATUSES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :organization_must_be_client

  scope :active, -> { where(status: "active") }
  scope :recent_first, -> { order(created_at: :desc) }

  before_validation :normalize_fields

  def active?
    status == "active"
  end

  private

    def normalize_fields
      self.full_name = full_name.to_s.squish
      self.email = email.to_s.strip.downcase.presence
      self.phone = phone.to_s.squish.presence
      self.job_title = job_title.to_s.squish.presence
      self.notes = notes.to_s.strip.presence
    end

    def organization_must_be_client
      return if organization.blank?
      return if organization.client?

      errors.add(:organization, "must be a client organisation")
    end
end
