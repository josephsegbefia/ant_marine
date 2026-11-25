# frozen_string_literal: true

class Quote < ApplicationRecord
  STATUSES = %w[draft pending_review returned_for_correction approved_for_issuance issued withdrawn superseded].freeze
  EDITABLE_STATUSES = %w[draft returned_for_correction].freeze
  DELIVERY_STATES = %w[not_prepared prepared delivery_pending delivery_attempted delivered delivery_failed].freeze
  SUPPORTED_CURRENCIES = %w[GHS USD EUR GBP].freeze
  RECIPIENT_ATTRIBUTES = %w[client_organization_id service_id prospective_client].freeze
  PROSPECTIVE_KEYS = %w[company_name contact_name email phone address].freeze

  belongs_to :organization
  belongs_to :client_organization, class_name: "Organization", optional: true
  belongs_to :service, optional: true
  belongs_to :service_inquiry, optional: true
  belongs_to :current_revision, class_name: "QuoteRevision", optional: true
  belongs_to :created_by_membership, class_name: "Membership", optional: true
  belongs_to :updated_by_membership, class_name: "Membership", optional: true

  has_many :quote_revisions, dependent: :restrict_with_exception
  has_many :quote_deliveries, dependent: :restrict_with_exception
  has_many :quote_portal_releases, dependent: :restrict_with_exception
  has_many :quote_responses, dependent: :restrict_with_exception

  validates :reference_number, presence: true, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }
  validates :delivery_state, inclusion: { in: DELIVERY_STATES }
  validate :client_organization_must_be_an_active_client, if: :client_organization_id_changed?
  validate :service_must_belong_to_organization, if: :service_id_changed?
  validate :recipient_locked_outside_editing, on: :update
  validate :service_inquiry_link_is_permanent, on: :update
  validate :service_inquiry_belongs_to_organization, if: :service_inquiry_id_changed?

  scope :for_ant_marine, -> { joins(:organization).where(organizations: { kind: "ant_marine" }) }
  scope :recent_first, -> { order(created_at: :desc) }

  def self.assignable_client_organizations(organization)
    Organization.client.active.where.not(id: organization.id)
  end

  def self.assignable_services(organization)
    Service.published_catalogue.where(organization_id: organization.id)
  end

  def editable?
    status.in?(EDITABLE_STATUSES) && current_revision.present? && current_revision.mutable?
  end

  def prospective_value(key)
    (prospective_client || {})[key.to_s].to_s
  end

  def client_label
    client_organization&.name.presence || prospective_value("company_name").presence || "Prospective client"
  end

  def display_title
    current_revision&.title.presence || "Untitled quotation"
  end

  def total_amount
    current_revision&.total_cents.to_i
  end

  def currency
    current_revision&.currency.presence || "GHS"
  end

  def next_action_label
    case status
    when "draft" then "Continue draft"
    when "pending_review" then "Awaiting reviewer decision"
    when "returned_for_correction" then "Make the requested corrections"
    when "approved_for_issuance" then "Approved — not yet sent to the client"
    when "issued" then "Sent — delivery not confirmed"
    when "withdrawn" then "Withdrawn"
    when "superseded" then "Replaced by a newer version"
    else "View"
    end
  end

  def latest_correction_request
    AuditEvent.where(subject_type: "Quote", subject_id: id, event_type: "quote.return_for_correction")
              .order(occurred_at: :desc).first
  end

  private

    def client_organization_must_be_an_active_client
      return if client_organization_id.blank?
      return if organization && self.class.assignable_client_organizations(organization).exists?(id: client_organization_id)

      errors.add(:client_organization_id, "Choose a client organisation from the list.")
    end

    def service_must_belong_to_organization
      return if service_id.blank?
      return if organization && self.class.assignable_services(organization).exists?(id: service_id)

      errors.add(:service_id, "Choose a published service from the list.")
    end

    def recipient_locked_outside_editing
      return if status_in_database.in?(EDITABLE_STATUSES)
      return unless (changed & RECIPIENT_ATTRIBUTES).any?

      errors.add(:base, "The client and service cannot be changed while this quotation is #{status_in_database.humanize.downcase}.")
    end

    def service_inquiry_link_is_permanent
      return unless service_inquiry_id_changed? && service_inquiry_id_in_database.present?

      errors.add(:base, "The enquiry linked to this quotation cannot be changed.")
    end

    def service_inquiry_belongs_to_organization
      return if service_inquiry.nil? || service_inquiry.organization_id == organization_id

      errors.add(:base, "This enquiry belongs to a different organisation.")
    end
end
