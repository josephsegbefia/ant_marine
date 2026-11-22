# frozen_string_literal: true

module Authorization
  module OwnerProtection
    class ProtectedRoleViolation < StandardError
      attr_reader :message

      def initialize(message = "This change would remove the last protected administrator.")
        @message = message
        super(message)
      end
    end

    module_function

    def protected_role_key?(role_key)
      role_key.in?(%w[staff.super_administrator client.org_owner])
    end

    def last_active_super_admin?(organization:, excluding: nil)
      return false unless organization.ant_marine?

      scope = Membership.active.where(organization: organization, role_key: "staff.super_administrator")
      scope = scope.where.not(id: excluding.id) if excluding
      scope.none?
    end

    def last_active_org_owner?(organization:, excluding: nil)
      return false unless organization.client?

      scope = Membership.active.where(organization: organization, role_key: "client.org_owner")
      scope = scope.where.not(id: excluding.id) if excluding
      scope.none?
    end

    def ensure_not_last_protected!(membership:)
      if membership.role_key == "staff.super_administrator" &&
          last_active_super_admin?(organization: membership.organization, excluding: membership)
        raise ProtectedRoleViolation, "Cannot remove the last Super Administrator."
      end

      if membership.role_key == "client.org_owner" &&
          last_active_org_owner?(organization: membership.organization, excluding: membership)
        raise ProtectedRoleViolation, "Cannot remove the last Organisation Owner."
      end
    end
  end
end
