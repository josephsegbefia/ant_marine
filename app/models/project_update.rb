# frozen_string_literal: true

class ProjectUpdate < ApplicationRecord
  VISIBILITIES = %w[client internal].freeze

  belongs_to :project
  belongs_to :author_membership, class_name: "Membership"

  validates :body, presence: true, length: { maximum: 5_000 }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :published_at, presence: true

  scope :client_visible, -> { where(visibility: "client") }
  scope :recent_first, -> { order(published_at: :desc, id: :desc) }

  def client_visible?
    visibility == "client"
  end
end
