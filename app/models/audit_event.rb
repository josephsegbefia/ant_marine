# frozen_string_literal: true

class AuditEvent < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :actor_membership, class_name: "Membership", optional: true

  validates :event_type, presence: true
  validates :metadata, exclusion: { in: [ nil ] }
  validates :occurred_at, presence: true

  def self.record!(event_type:, organization: nil, actor_membership: nil, subject: nil, metadata: {})
    create!(
      event_type: event_type,
      organization: organization,
      actor_membership: actor_membership,
      subject_type: subject&.class&.name,
      subject_id: subject&.id,
      metadata: sanitize_metadata(metadata),
      occurred_at: Time.current
    )
  end

  def self.sanitize_metadata(metadata)
    metadata.stringify_keys.except("token", "password", "password_confirmation", "raw_token", "token_digest")
  end
end
