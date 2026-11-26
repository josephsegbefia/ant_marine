# frozen_string_literal: true

class Project < ApplicationRecord
  INTERNAL_STATUSES = %w[
    planning scheduled in_progress technical_review report_ready
    completed closed on_hold cancelled
  ].freeze

  CLIENT_STATUSES = %w[
    planning scheduled in_progress on_hold completed cancelled closed
  ].freeze

  MODES = %w[simulated].freeze

  CLIENT_STATUS_MAP = {
    "planning" => "planning",
    "scheduled" => "scheduled",
    "in_progress" => "in_progress",
    "technical_review" => "in_progress",
    "report_ready" => "in_progress",
    "completed" => "completed",
    "closed" => "closed",
    "on_hold" => "on_hold",
    "cancelled" => "cancelled"
  }.freeze

  belongs_to :operating_organization, class_name: "Organization"
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :service, optional: true
  belongs_to :service_inquiry, optional: true
  belongs_to :quote
  belongs_to :quote_revision
  belongs_to :quote_response
  belongs_to :quote_portal_release
  belongs_to :created_by_membership, class_name: "Membership"
  belongs_to :coordinator_membership, class_name: "Membership", optional: true

  has_many :assignments, dependent: :restrict_with_exception
  has_many :active_assignments, -> { where(active: true) }, class_name: "Assignment"
  has_many :project_milestones, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :project
  has_many :tasks, dependent: :destroy
  has_many :schedule_events, dependent: :destroy
  has_many :project_status_events, dependent: :destroy
  has_many :project_updates, dependent: :destroy
  has_many :documents, dependent: :restrict_with_exception
  has_many :upload_requests, dependent: :restrict_with_exception

  validates :reference_number, presence: true, uniqueness: true
  validates :title, presence: true, length: { maximum: 200 }
  validates :internal_status, inclusion: { in: INTERNAL_STATUSES }
  validates :client_status, inclusion: { in: CLIENT_STATUSES }
  validates :mode, inclusion: { in: MODES }
  validates :quote_revision_id, uniqueness: true
  validates :quote_response_id, uniqueness: true
  validate :mode_immutable, on: :update
  validate :commercial_source_immutable, on: :update

  scope :simulated, -> { where(mode: "simulated") }
  scope :for_client_organization, ->(org) { where(client_organization_id: org.id) }
  scope :for_operating_organization, ->(org) { where(operating_organization_id: org.id) }
  scope :not_archived, -> { where(archived_at: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def simulated?
    mode == "simulated"
  end

  def open?
    !internal_status.in?(%w[completed closed cancelled])
  end

  def active_assignment_for(user)
    active_assignments.find_by(user_id: user.id)
  end

  def assigned?(user)
    active_assignment_for(user).present?
  end

  def progress_summary
    eligible = project_milestones.where(counts_toward_progress: true).where.not(status: "cancelled")
    total = eligible.count
    done = eligible.where(status: "completed").count
    { completed: done, total: total, label: total.zero? ? "No milestones yet" : "#{done} of #{total} milestones complete" }
  end

  def progress_ratio
    summary = progress_summary
    return 0.0 if summary[:total].zero?

    summary[:completed].to_f / summary[:total]
  end

  def sync_client_status!
    mapped = CLIENT_STATUS_MAP.fetch(internal_status)
    update_column(:client_status, mapped) if client_status != mapped
  end

  def client_status_label
    case client_status
    when "planning" then "Planning"
    when "scheduled" then "Scheduled"
    when "in_progress" then "In progress"
    when "on_hold" then "On hold"
    when "completed" then "Completed"
    when "cancelled" then "Cancelled"
    when "closed" then "Closed"
    else client_status.humanize
    end
  end

  def internal_status_label
    {
      "planning" => "Planning",
      "scheduled" => "Scheduled",
      "in_progress" => "In progress",
      "technical_review" => "Technical review",
      "report_ready" => "Report ready",
      "completed" => "Completed",
      "closed" => "Closed",
      "on_hold" => "On hold",
      "cancelled" => "Cancelled"
    }.fetch(internal_status, internal_status.humanize)
  end

  def next_confirmed_activity
    schedule_events.where(confirmation_state: "confirmed")
                   .where("starts_at >= ?", Time.current)
                   .order(:starts_at)
                   .first
  end

  private

    def mode_immutable
      return unless mode_changed? && persisted?

      errors.add(:mode, "cannot change a project’s simulation classification")
    end

    def commercial_source_immutable
      %w[quote_id quote_revision_id quote_response_id quote_portal_release_id
         client_organization_id commercial_snapshot].each do |attr|
        next unless will_save_change_to_attribute?(attr)

        errors.add(attr, "is fixed from the accepted commercial offer")
      end
    end
end
