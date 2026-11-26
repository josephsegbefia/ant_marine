# frozen_string_literal: true

class DocumentRelease < ApplicationRecord
  CLASSIFICATIONS = Storage::Asset::CLASSIFICATIONS
  RELEASE_KINDS = %w[client_share].freeze

  belongs_to :document
  belongs_to :document_version
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :released_by_membership, class_name: "Membership"

  validates :released_at, presence: true
  validates :classification, inclusion: { in: CLASSIFICATIONS }
  validates :release_kind, inclusion: { in: RELEASE_KINDS }
  validate :version_belongs_to_document
  validate :client_matches_document

  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def revoked?
    revoked_at.present?
  end

  private

    def version_belongs_to_document
      return if document_version.blank? || document.blank?
      return if document_version.document_id == document_id

      errors.add(:document_version, "must belong to this document")
    end

    def client_matches_document
      return if client_organization.blank? || document.blank?
      return if client_organization_id == document.client_organization_id

      errors.add(:client_organization, "must match the document client organisation")
    end
end
