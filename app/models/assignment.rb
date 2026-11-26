# frozen_string_literal: true

class Assignment < ApplicationRecord
  KINDS = %w[coordinator lead_surveyor surveyor technical_reviewer collaborator].freeze
  SCOPES = %w[delivery review collaborator].freeze

  KIND_DEFAULT_SCOPE = {
    "coordinator" => "delivery",
    "lead_surveyor" => "delivery",
    "surveyor" => "delivery",
    "technical_reviewer" => "review",
    "collaborator" => "collaborator"
  }.freeze

  belongs_to :project
  belongs_to :user
  belongs_to :membership
  belongs_to :assigned_by_membership, class_name: "Membership"

  validates :assignment_kind, inclusion: { in: KINDS }
  validates :access_scope, inclusion: { in: SCOPES }
  validate :membership_matches_user
  validate :membership_is_staff_of_operating_org

  scope :active, -> { where(active: true) }
  scope :for_user, ->(user) { where(user_id: user.id) }

  def kind_label
    assignment_kind.tr("_", " ").humanize
  end

  def scope_label
    access_scope.humanize
  end

  def deactivate!(ended_at: Time.current)
    update!(active: false, ended_at: ended_at)
  end

  private

    def membership_matches_user
      return if membership.blank? || user.blank?
      return if membership.user_id == user_id

      errors.add(:membership, "must belong to the assigned person")
    end

    def membership_is_staff_of_operating_org
      return if membership.blank? || project.blank?
      return if membership.organization_id == project.operating_organization_id && membership.staff_domain?

      errors.add(:membership, "must be active ANT Marine staff for this project")
    end
end
