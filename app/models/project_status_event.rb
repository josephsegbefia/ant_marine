# frozen_string_literal: true

class ProjectStatusEvent < ApplicationRecord
  belongs_to :project
  belongs_to :actor_membership, class_name: "Membership"

  validates :to_status, presence: true
  validates :occurred_at, presence: true
end
