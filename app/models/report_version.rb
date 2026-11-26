# frozen_string_literal: true

class ReportVersion < ApplicationRecord
  STATUSES = %w[draft submitted_for_review changes_requested approved].freeze

  belongs_to :report
  belongs_to :authored_by_membership, class_name: "Membership"
  belongs_to :submitted_by_membership, class_name: "Membership", optional: true
  belongs_to :storage_asset, class_name: "Storage::Asset", optional: true

  has_many :report_reviews, dependent: :destroy
  has_many :report_releases, dependent: :restrict_with_exception

  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :version_number, uniqueness: { scope: :report_id }
  validates :status, inclusion: { in: STATUSES }
  validates :title, presence: true, length: { maximum: 200 }
  validates :content_json, presence: true

  def draft?
    status == "draft"
  end

  def approved?
    status == "approved"
  end

  def status_label
    status.tr("_", " ").humanize
  end

  def label
    "Version #{version_number}"
  end
end
