# frozen_string_literal: true

class ScheduleEvent < ApplicationRecord
  CONFIRMATION_STATES = %w[proposed confirmed rescheduled cancelled completed].freeze
  ACTIVITY_TYPES = %w[site_work mobilization meeting inspection other].freeze

  belongs_to :project
  belongs_to :responsible_membership, class_name: "Membership", optional: true
  belongs_to :created_by_membership, class_name: "Membership"
  belongs_to :confirmed_by_membership, class_name: "Membership", optional: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :confirmation_state, inclusion: { in: CONFIRMATION_STATES }
  validates :activity_type, inclusion: { in: ACTIVITY_TYPES }
  validates :starts_at, :ends_at, presence: true
  validate :starts_before_ends

  scope :upcoming, -> { where("starts_at >= ?", Time.current).where.not(confirmation_state: "cancelled") }
  scope :confirmed, -> { where(confirmation_state: "confirmed") }
  scope :client_visible, -> { where(confirmation_state: %w[confirmed completed]) }

  def proposed?
    confirmation_state == "proposed"
  end

  def confirmed?
    confirmation_state == "confirmed"
  end

  def cancelled?
    confirmation_state == "cancelled"
  end

  def state_label
    confirmation_state.humanize
  end

  private

    def starts_before_ends
      return if starts_at.blank? || ends_at.blank?
      return if starts_at < ends_at

      errors.add(:ends_at, "must be after the start time")
    end
end
