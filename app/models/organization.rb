class Organization < ApplicationRecord
  KINDS = %w[ant_marine client].freeze
  STATUSES = %w[active archived].freeze

  has_many :memberships, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :public_site_pages, dependent: :destroy

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9\-]+\z/ }

  validate :single_active_ant_marine_org, if: -> { kind == "ant_marine" && archived_at.nil? }

  scope :active, -> { where(status: "active", archived_at: nil) }
  scope :client, -> { where(kind: "client") }

  def ant_marine?
    kind == "ant_marine"
  end

  def client?
    kind == "client"
  end

  def active?
    status == "active" && archived_at.nil?
  end

  def self.ant_marine!
    active.find_by!(kind: "ant_marine")
  end

  private

    def single_active_ant_marine_org
      existing = self.class.active.where(kind: "ant_marine").where.not(id: id)
      errors.add(:kind, "only one active ANT Marine organisation is allowed") if existing.exists?
    end
end
