# frozen_string_literal: true

class QuoteResponse < ApplicationRecord
  RESPONSES = %w[accepted declined changes_requested].freeze
  MODES = %w[simulated].freeze
  TERMINAL = %w[accepted declined].freeze

  self.record_timestamps = false

  belongs_to :quote
  belongs_to :quote_revision
  belongs_to :quote_portal_release
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :responded_by_membership, class_name: "Membership"
  belongs_to :responded_by_user, class_name: "User"

  validates :response, inclusion: { in: RESPONSES }
  validates :mode, inclusion: { in: MODES }
  validates :idempotency_key, presence: true, uniqueness: true
  validates :confirmed_at, presence: true
  validates :reason, presence: true, if: -> { response.in?(%w[declined changes_requested]) }

  scope :terminal, -> { where(response: TERMINAL) }
  scope :for_client_organization, ->(org) { where(client_organization_id: org.id) }
  scope :recent_first, -> { order(created_at: :desc) }

  def accepted?
    response == "accepted"
  end

  def declined?
    response == "declined"
  end

  def changes_requested?
    response == "changes_requested"
  end

  def simulated?
    mode == "simulated"
  end

  def terminal?
    response.in?(TERMINAL)
  end

  def client_status_label
    case response
    when "accepted" then simulated? ? "Accepted (simulated test)" : "Accepted"
    when "declined" then simulated? ? "Declined (simulated test)" : "Declined"
    when "changes_requested" then "Changes requested"
    else response.to_s.humanize
    end
  end
end
