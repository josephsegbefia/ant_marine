class Organization < ApplicationRecord
  KINDS = %w[ant_marine client].freeze
  STATUSES = %w[active archived].freeze
  PROFILE_KEYS = Clients::CreateOrganization::PROFILE_KEYS

  has_many :memberships, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :public_site_pages, dependent: :destroy
  has_many :articles, dependent: :destroy
  has_many :case_studies, dependent: :destroy
  has_many :training_offerings, dependent: :destroy
  has_many :public_resources, dependent: :destroy
  has_many :quotes, dependent: :destroy
  has_many :client_quotes, class_name: "Quote", foreign_key: :client_organization_id, inverse_of: :client_organization,
                           dependent: :nullify
  has_many :client_service_inquiries, class_name: "ServiceInquiry", foreign_key: :client_organization_id,
                                      inverse_of: :client_organization, dependent: :nullify
  has_many :quote_portal_releases, foreign_key: :client_organization_id, inverse_of: :client_organization,
                                   dependent: :restrict_with_exception
  has_many :client_contacts, dependent: :destroy
  has_many :quote_responses, foreign_key: :client_organization_id, inverse_of: :client_organization,
                             dependent: :restrict_with_exception

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9\-]+\z/ }
  validates :reference_number, uniqueness: true, allow_nil: true

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

  PROFILE_KEYS.each do |key|
    define_method(key) { profile_value(key) }
    define_method("#{key}=") do |value|
      self.profile = (profile || {}).merge(key.to_s => value.to_s.squish.presence)
    end
  end

  def profile_value(key)
    (profile || {})[key.to_s].to_s.presence
  end

  def portal_member_count
    if memberships.loaded?
      memberships.count { |membership| membership.status == "active" }
    else
      memberships.active.count
    end
  end

  def pending_invitation_count
    if invitations.loaded?
      invitations.count { |invitation| invitation.status == "pending" }
    else
      invitations.pending.count
    end
  end

  def self.duplicate_suggestions(name:, email: nil, limit: 5)
    scope = client.active
    terms = []
    binds = {}
    if name.present?
      terms << "organizations.name ILIKE :name"
      binds[:name] = "%#{ActiveRecord::Base.sanitize_sql_like(name.to_s.squish)}%"
    end
    if email.present?
      terms << "organizations.profile->>'business_email' ILIKE :email OR organizations.profile->>'primary_contact_email' ILIKE :email"
      binds[:email] = email.to_s.strip.downcase
    end
    return none if terms.empty?

    scope.where(terms.join(" OR "), binds).order(:name).limit(limit)
  end

  private

    def single_active_ant_marine_org
      existing = self.class.active.where(kind: "ant_marine").where.not(id: id)
      errors.add(:kind, "only one active ANT Marine organisation is allowed") if existing.exists?
    end
end
