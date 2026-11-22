# frozen_string_literal: true

module Authorization
  module ProtectedRules
    module_function

    def membership_may_check?(membership, permission_key)
      return false if membership.nil?

      definition = PermissionCatalogue.find(permission_key)
      return false unless definition

      applicable = PermissionCatalogue.applicable_keys_for_membership(membership)
      applicable.include?(permission_key)
    end

    def client_cannot_hold_staff_only?(membership, permission)
      return false unless membership.client_domain?

      permission.domain == "staff"
    end
  end
end
