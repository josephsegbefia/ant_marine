# frozen_string_literal: true

class Task < ApplicationRecord
  STATUSES = %w[todo in_progress blocked completed cancelled].freeze
  PRIORITIES = %w[low normal high urgent].freeze

  belongs_to :project
  belongs_to :assignee_membership, class_name: "Membership", optional: true
  belongs_to :created_by_membership, class_name: "Membership"

  validates :title, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }

  scope :open, -> { where(status: %w[todo in_progress blocked]) }
  scope :overdue, -> {
    open.where.not(due_on: nil).where("due_on < ?", Time.zone.today)
  }

  def overdue?
    due_on.present? && due_on < Time.zone.today && status.in?(%w[todo in_progress blocked])
  end

  def completed?
    status == "completed"
  end

  def status_label
    {
      "todo" => "To do",
      "in_progress" => "In progress",
      "blocked" => "Blocked",
      "completed" => "Completed",
      "cancelled" => "Cancelled"
    }.fetch(status)
  end
end
