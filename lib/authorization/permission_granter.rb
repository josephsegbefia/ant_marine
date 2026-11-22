# frozen_string_literal: true

module Authorization
  class PermissionGranter
    class Denied < StandardError
      attr_reader :message

      def initialize(message = "You are not allowed to change this permission.")
        @message = message
        super(message)
      end
    end

    def initialize(actor_membership:)
      @actor = actor_membership
      @actor_perms = EffectivePermissions.new(actor_membership)
    end

    def grant_allow!(target_membership:, permission_key:, reason: nil)
      apply_override!(target_membership:, permission_key:, effect: "allow", reason:)
    end

    def grant_deny!(target_membership:, permission_key:, reason: nil)
      apply_override!(target_membership:, permission_key:, effect: "deny", reason:)
    end

    def remove_override!(target_membership:, permission_key:, reason: nil)
      validate_actor!
      validate_same_organization!(target_membership)
      permission = Permission.find_by!(key: permission_key)
      validate_management_rights!(target_membership, permission)

      PermissionOverride.transaction do
        target_membership.lock!
        override = PermissionOverride.find_by(membership: target_membership, permission: permission)
        raise Denied, "No override exists for this permission." unless override

        previous = override.effect
        override.destroy!
        target_membership.bump_permission_epoch!
        Audit.override_removed(
          actor_membership: @actor,
          target_membership: target_membership,
          permission: permission,
          previous_effect: previous,
          reason: reason
        )
      end
    end

    private

      def apply_override!(target_membership:, permission_key:, effect:, reason:)
        validate_actor!
        validate_same_organization!(target_membership)
        permission = Permission.find_by!(key: permission_key)
        validate_management_rights!(target_membership, permission)
        validate_override_rule!(permission, effect)
        validate_grant_bounds!(permission, effect)

        PermissionOverride.transaction do
          target_membership.lock!
          override = PermissionOverride.find_or_initialize_by(membership: target_membership, permission: permission)
          previous = override.persisted? ? override.effect : nil
          override.assign_attributes(effect: effect, granted_by_membership: @actor, reason: reason)
          override.save!
          target_membership.bump_permission_epoch!
          Audit.override_granted(
            actor_membership: @actor,
            target_membership: target_membership,
            permission: permission,
            effect: effect,
            previous_effect: previous,
            reason: reason
          )
        end
      end

      def validate_actor!
        raise Denied unless @actor&.status == "active" && @actor.organization&.active?
      end

      def validate_same_organization!(target_membership)
        raise Denied, "Target membership is in another organisation." if target_membership.organization_id != @actor.organization_id
      end

      def validate_management_rights!(target_membership, permission)
        if @actor.staff_domain?
          raise Denied unless @actor_perms.allowed?("team.manage_staff_permissions")
        elsif @actor.client_domain?
          if @actor_perms.allowed?("team.manage_permissions")
            return
          end
          if @actor_perms.allowed?("team.manage_team_delegated") && permission.override_rule != "protected"
            return
          end

          raise Denied
        else
          raise Denied
        end
      end

      def validate_override_rule!(permission, effect)
        if permission.override_rule == "protected"
          raise Denied, "This permission is managed by role assignment only."
        end
        raise Denied, "This permission only supports explicit deny overrides." if permission.override_rule == "deny_only" && effect == "allow"
      end

      def validate_grant_bounds!(permission, effect)
        return if effect == "deny"
        return if @actor_perms.allowed?(permission.key)

        raise Denied, "You cannot grant a permission you do not hold."
      end
  end
end
