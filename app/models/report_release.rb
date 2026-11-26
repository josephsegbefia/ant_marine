# frozen_string_literal: true

class ReportRelease < ApplicationRecord
  belongs_to :report
  belongs_to :report_version
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :released_by_membership, class_name: "Membership"

  validates :released_at, presence: true
  validates :artifact_checksum_sha256, presence: true
  validate :version_belongs_to_report
  validate :client_matches_report

  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def revoked?
    revoked_at.present?
  end

  private

    def version_belongs_to_report
      return if report_version.blank? || report.blank?
      return if report_version.report_id == report_id

      errors.add(:report_version, "must belong to this report")
    end

    def client_matches_report
      return if client_organization.blank? || report.blank?
      return if client_organization_id == report.client_organization_id

      errors.add(:client_organization, "must match the report client organisation")
    end
end
