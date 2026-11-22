# frozen_string_literal: true

module Authorization
  class Audit
    def self.override_granted(actor_membership:, target_membership:, permission:, effect:, previous_effect: nil, reason: nil)
      record("permission.override_granted", actor_membership:, target_membership:, permission:, effect:, previous_effect:, reason:)
    end

    def self.override_removed(actor_membership:, target_membership:, permission:, previous_effect:, reason: nil)
      AuditEvent.record!(
        event_type: "permission.override_removed",
        organization: target_membership.organization,
        actor_membership: actor_membership,
        subject: target_membership,
        metadata: {
          "target_membership_id" => target_membership.id,
          "permission_key" => permission.key,
          "previous_effect" => previous_effect,
          "reason" => reason
        }.compact
      )
    end

    def self.change_rejected(actor_membership:, target_membership: nil, permission_key: nil, reason:)
      AuditEvent.record!(
        event_type: "permission.change_rejected",
        organization: actor_membership&.organization,
        actor_membership: actor_membership,
        subject: target_membership,
        metadata: {
          "permission_key" => permission_key,
          "reason" => reason
        }.compact
      )
    end

    def self.record(event_type, actor_membership:, target_membership:, permission:, effect:, previous_effect: nil, reason: nil)
      AuditEvent.record!(
        event_type: event_type,
        organization: target_membership.organization,
        actor_membership: actor_membership,
        subject: target_membership,
        metadata: {
          "target_membership_id" => target_membership.id,
          "permission_key" => permission.key,
          "effect" => effect,
          "previous_effect" => previous_effect,
          "reason" => reason
        }.compact
      )
    end
  end
end
