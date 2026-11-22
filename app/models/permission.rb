# frozen_string_literal: true

class Permission < ApplicationRecord
  OVERRIDE_RULES = %w[yes protected deny_only].freeze
  DOMAINS = %w[staff client both].freeze

  has_many :role_permissions, dependent: :destroy
  has_many :permission_overrides, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :display_name, :category, :domain, :override_rule, presence: true
  validates :override_rule, inclusion: { in: OVERRIDE_RULES }
  validates :domain, inclusion: { in: DOMAINS }
  validates :catalogue_version, numericality: { only_integer: true, greater_than: 0 }

  scope :for_staff, -> { where(domain: %w[staff both]) }
  scope :for_client, -> { where(domain: %w[client both]) }

  def staff_applicable?
    domain.in?(%w[staff both])
  end

  def client_applicable?
    domain.in?(%w[client both])
  end
end
