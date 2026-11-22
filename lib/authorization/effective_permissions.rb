# frozen_string_literal: true

module Authorization
  class EffectivePermissions
    def self.allowed?(membership:, permission_key:)
      new(membership).allowed?(permission_key)
    end

    def self.for(membership)
      new(membership)
    end

    def initialize(membership)
      @membership = membership
    end

    def allowed?(permission_key)
      key = permission_key.to_s
      return false unless active_membership?
      return false unless PermissionCatalogue.known?(key)
      return false unless ProtectedRules.membership_may_check?(@membership, key)

      permission = Permission.find_by!(key: key)
      return false if ProtectedRules.client_cannot_hold_staff_only?(@membership, permission)

      override = overrides_by_permission_id[permission.id]
      return false if override&.deny?

      return true if override&.allow?

      role_default?(permission.id)
    end

    private

      def active_membership?
        @membership&.status == "active" && @membership.organization&.active?
      end

      def role_default?(permission_id)
        role_permission_ids.include?(permission_id)
      end

      def role_permission_ids
        @role_permission_ids ||= RolePermission.where(role_key: @membership.role_key).pluck(:permission_id).to_set
      end

      def overrides_by_permission_id
        @overrides_by_permission_id ||= @membership.permission_overrides.includes(:permission).index_by(&:permission_id)
      end
  end
end
