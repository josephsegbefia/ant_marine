# frozen_string_literal: true

class ReportVersionPolicy < ApplicationPolicy
  def update?
    Reports::Access.can_draft?(membership, record.report) && record.draft?
  end

  def review?
    Reports::Access.can_review?(membership, record.report)
  end

  def release?
    Reports::Access.can_release?(membership, record.report)
  end

  def download?
    return false unless record.approved?

    if membership.staff_domain?
      Reports::Access.can_view_metadata?(membership, record.report)
    elsif membership.client_domain?
      release = record.report.report_releases.active.find_by(client_organization_id: membership.organization_id)
      release.present? && release.report_version_id == record.id
    else
      false
    end
  end
end
