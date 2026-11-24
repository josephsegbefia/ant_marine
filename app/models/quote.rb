# frozen_string_literal: true

class Quote < ApplicationRecord
  STATUSES = %w[draft pending_review approved_for_issuance issued withdrawn superseded].freeze
  DELIVERY_STATES = %w[not_prepared prepared delivery_pending delivery_attempted delivered delivery_failed].freeze
  SUPPORTED_CURRENCIES = %w[GHS USD EUR GBP].freeze

  belongs_to :organization
  belongs_to :client_organization, class_name: "Organization", optional: true
  belongs_to :service, optional: true
  belongs_to :current_revision, class_name: "QuoteRevision", optional: true
  belongs_to :created_by_membership, class_name: "Membership", optional: true
  belongs_to :updated_by_membership, class_name: "Membership", optional: true

  has_many :quote_revisions, dependent: :destroy

  validates :reference_number, presence: true, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }
  validates :delivery_state, inclusion: { in: DELIVERY_STATES }

  scope :for_ant_marine, -> { joins(:organization).where(organizations: { kind: "ant_marine" }) }
  scope :recent_first, -> { order(created_at: :desc) }

  def editable?
    status.in?(%w[draft pending_review]) && current_revision&.mutable?
  end

  def client_label
    client_organization&.name.presence || prospective_client["company_name"].presence || "Prospective client"
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
    when "pending_review" then "Awaiting review"
    when "approved_for_issuance" then "Ready to issue"
    when "issued" then "Issued to client"
    when "withdrawn" then "Withdrawn"
    when "superseded" then "Superseded"
    else "View"
    end
  end
end
