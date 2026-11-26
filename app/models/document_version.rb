# frozen_string_literal: true

class DocumentVersion < ApplicationRecord
  self.record_timestamps = false

  belongs_to :document
  belongs_to :storage_asset, class_name: "Storage::Asset"
  belongs_to :uploaded_by_membership, class_name: "Membership"

  has_many :document_reviews, dependent: :destroy
  has_one :document_release, dependent: :restrict_with_exception

  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :filename, :content_type, :checksum_sha256, presence: true
  validates :byte_size, numericality: { greater_than: 0, only_integer: true }
  validates :version_number, uniqueness: { scope: :document_id }
  validate :storage_asset_belongs_to_operating_org

  def security_status
    storage_asset.scan_status
  end

  def downloadable?
    storage_asset.downloadable?
  end

  def label
    "Version #{version_number}"
  end

  private

    def storage_asset_belongs_to_operating_org
      return if storage_asset.blank? || document.blank?

      unless storage_asset.organization_id == document.operating_organization_id
        errors.add(:storage_asset, "must belong to the project operating organisation")
      end
    end
end
