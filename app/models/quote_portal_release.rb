# frozen_string_literal: true

class QuotePortalRelease < ApplicationRecord
  MODES = %w[simulated].freeze

  belongs_to :quote
  belongs_to :quote_revision
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :released_by_membership, class_name: "Membership"
  belongs_to :revoked_by_membership, class_name: "Membership", optional: true

  validates :mode, inclusion: { in: MODES }
  validates :released_at, presence: true
  validates :quote_revision_id, uniqueness: { scope: :client_organization_id }
  validate :revision_belongs_to_quote
  validate :client_organization_is_client
  validate :revision_is_eligible

  scope :active, -> { where(revoked_at: nil) }
  scope :for_client_organization, ->(org) { where(client_organization_id: org.id) }
  scope :simulated, -> { where(mode: "simulated") }

  def active?
    revoked_at.nil?
  end

  def simulated?
    mode == "simulated"
  end

  def revoke!(actor_membership:)
    return self if revoked_at.present?

    update!(revoked_at: Time.current, revoked_by_membership: actor_membership)
  end

  private

    def revision_belongs_to_quote
      return if quote_id.blank? || quote_revision_id.blank?
      return if quote_revision&.quote_id == quote_id

      errors.add(:quote_revision, "must belong to the quotation")
    end

    def client_organization_is_client
      return if client_organization.blank?
      return if client_organization.client? && client_organization.active?

      errors.add(:client_organization, "must be an active client organisation")
    end

    def revision_is_eligible
      return if quote_revision.blank?
      return if quote_revision.revision_status == "issued" || quote_revision.revision_status == "approved"

      # Simulated portal release requires an approved or issued frozen version.
      return if quote_revision.version_frozen?

      errors.add(:quote_revision, "must be an approved or issued version")
    end
end
