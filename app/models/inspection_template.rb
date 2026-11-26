# frozen_string_literal: true

class InspectionTemplate < ApplicationRecord
  STATUSES = %w[draft published archived].freeze

  belongs_to :operating_organization, class_name: "Organization"
  belongs_to :service, optional: true
  belongs_to :current_version, class_name: "InspectionTemplateVersion", optional: true

  has_many :inspection_template_versions, dependent: :restrict_with_exception

  validates :key, presence: true, length: { maximum: 100 }
  validates :title, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :key, uniqueness: { scope: :operating_organization_id }

  scope :published, -> { where(status: "published") }
  scope :for_operating_organization, ->(org) { where(operating_organization_id: org.id) }

  def status_label
    status.humanize
  end

  def published?
    status == "published"
  end
end
