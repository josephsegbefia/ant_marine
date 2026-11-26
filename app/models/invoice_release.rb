# frozen_string_literal: true

class InvoiceRelease < ApplicationRecord
  belongs_to :invoice
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :released_by_membership, class_name: "Membership"
  belongs_to :revoked_by_membership, class_name: "Membership", optional: true
  belongs_to :storage_asset, class_name: "Storage::Asset"

  validates :released_at, presence: true
  validates :artifact_checksum_sha256, presence: true
  validate :client_matches_invoice

  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def revoked?
    revoked_at.present?
  end

  private

    def client_matches_invoice
      return if invoice.blank? || client_organization_id.blank?
      return if client_organization_id == invoice.client_organization_id

      errors.add(:client_organization, "must match the invoice client organisation")
    end
end
