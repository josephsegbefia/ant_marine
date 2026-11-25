# frozen_string_literal: true

# One attempt to send one exact approved quotation version to one recipient.
# "Accepted by provider" means the mail system took the message; it is not proof the
# recipient received it. "Delivery confirmed" requires provider evidence (none wired yet).
class QuoteDelivery < ApplicationRecord
  STATUSES = %w[prepared queued sending accepted_by_provider failed outcome_unknown delivery_confirmed cancelled].freeze
  LIVE_STATUSES = %w[prepared queued sending accepted_by_provider outcome_unknown delivery_confirmed].freeze
  IN_FLIGHT_STATUSES = %w[prepared queued sending].freeze
  LOCAL_ADAPTERS = %w[test file].freeze

  QUOTE_DELIVERY_STATES = {
    "prepared" => "prepared",
    "queued" => "delivery_pending",
    "sending" => "delivery_pending",
    "accepted_by_provider" => "delivery_attempted",
    "outcome_unknown" => "delivery_attempted",
    "failed" => "delivery_failed",
    "delivery_confirmed" => "delivered",
    "cancelled" => "not_prepared"
  }.freeze

  belongs_to :organization
  belongs_to :quote
  belongs_to :quote_revision
  belongs_to :requested_by_membership, class_name: "Membership"
  belongs_to :dispatched_by_membership, class_name: "Membership", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :channel, inclusion: { in: %w[email] }
  validates :recipient_email, presence: true, format: { with: ServiceInquiry::EMAIL_FORMAT }
  validates :idempotency_key, presence: true, uniqueness: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def self.in_flight_for?(revision)
    revision.present? && where(quote_revision_id: revision.id, status: IN_FLIGHT_STATUSES).exists?
  end

  def self.live_for(revision)
    where(quote_revision_id: revision.id, status: LIVE_STATUSES).order(:id).last
  end

  def local_adapter?
    LOCAL_ADAPTERS.include?(delivery_adapter)
  end

  def in_flight?
    IN_FLIGHT_STATUSES.include?(status)
  end

  def status_label
    case status
    when "prepared" then "Prepared — not sent"
    when "queued" then "Queued — not sent yet"
    when "sending" then "Sending — waiting for the mail system"
    when "accepted_by_provider"
      local_adapter? ? "Accepted by the test mail system — no real email was sent" : "Accepted by the mail provider — delivery not confirmed"
    when "failed" then "Delivery failed — not sent"
    when "outcome_unknown" then "Outcome unknown — check with the recipient before sending again"
    when "delivery_confirmed" then "Delivery confirmed by the mail provider"
    when "cancelled" then "Cancelled — not sent"
    else status.humanize
    end
  end

  def badge_variant
    case status
    when "prepared", "queued", "sending" then "ant-badge--blue"
    when "accepted_by_provider" then "ant-badge--teal"
    when "delivery_confirmed" then "ant-badge--good"
    when "failed", "outcome_unknown" then "ant-badge--warn"
    else "ant-badge--muted"
    end
  end

  def quote_delivery_state
    QUOTE_DELIVERY_STATES.fetch(status)
  end
end
