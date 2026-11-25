# frozen_string_literal: true

module Clients
  class MembershipLifecycle
    class Error < StandardError; end
    class Denied < Error; end

    def self.suspend!(actor_membership:, membership:)
      new(actor_membership: actor_membership).suspend!(membership: membership)
    end

    def self.revoke!(actor_membership:, membership:)
      new(actor_membership: actor_membership).revoke!(membership: membership)
    end

    def initialize(actor_membership:)
      @actor = actor_membership
    end

    def suspend!(membership:)
      authorize!(membership)
      membership.update!(status: "suspended")
      membership.bump_permission_epoch!
      membership.user.sessions.where(revoked_at: nil, membership_id: membership.id).find_each(&:revoke!)
      audit!("membership.suspended", membership)
      membership
    end

    def revoke!(membership:)
      authorize!(membership)
      membership.update!(status: "removed")
      membership.bump_permission_epoch!
      membership.user.sessions.where(revoked_at: nil, membership_id: membership.id).find_each(&:revoke!)
      audit!("membership.revoked", membership)
      membership
    end

    private

      def authorize!(membership)
        unless @actor&.staff_domain? && @actor.portal_access? &&
               Authorization::EffectivePermissions.allowed?(membership: @actor, permission_key: "team.suspend") &&
               membership.organization.client?
          raise Denied, "You are not allowed to change this membership."
        end
      end

      def audit!(event_type, membership)
        AuditEvent.record!(
          organization: Organization.ant_marine!,
          actor_membership: @actor,
          event_type: event_type,
          subject: membership,
          metadata: {
            "user_id" => membership.user_id,
            "client_organization_id" => membership.organization_id,
            "role_key" => membership.role_key,
            "status" => membership.status
          }
        )
      end
  end
end
