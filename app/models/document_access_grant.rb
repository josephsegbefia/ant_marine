# frozen_string_literal: true

class DocumentAccessGrant < ApplicationRecord
  belongs_to :document, optional: true
  belongs_to :project, optional: true
  belongs_to :user
  belongs_to :granted_by_membership, class_name: "Membership"

  validate :exactly_one_target
  validate :target_belongs_to_operating_org

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at > Time.current)
  end

  def grant_scope_document?(document_id)
    self.document_id == document_id
  end

  def grant_scope_project?(project_id)
    self.project_id == project_id
  end

  private

    def exactly_one_target
      if document_id.present? == project_id.present?
        errors.add(:base, "Grant must target exactly one document or one project")
      end
    end

    def target_belongs_to_operating_org
      return if granted_by_membership.blank?

      org_id = granted_by_membership.organization_id
      if document.present? && document.operating_organization_id != org_id
        errors.add(:document, "must belong to the granter’s organisation")
      end
      if project.present? && project.operating_organization_id != org_id
        errors.add(:project, "must belong to the granter’s organisation")
      end
    end
end
