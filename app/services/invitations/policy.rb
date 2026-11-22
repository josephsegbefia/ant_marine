# frozen_string_literal: true

module Invitations
  class Policy
    STAFF_ISSUER_ROLES = %w[staff.super_administrator staff.operations_manager].freeze
    CLIENT_ISSUER_ROLES = %w[client.org_owner client.org_administrator client.client_manager].freeze

    SUPER_ADMIN_STAFF_TARGETS = (RoleKeys::STAFF - %w[staff.super_administrator]).freeze
    OPS_MANAGER_STAFF_TARGETS = (RoleKeys::STAFF - %w[staff.super_administrator staff.operations_manager]).freeze
    CLIENT_INVITE_TARGETS = (RoleKeys::CLIENT - %w[client.org_owner]).freeze

    class Denied < StandardError
      attr_reader :message

      def initialize(message = "You are not allowed to send this invitation.")
        @message = message
        super(message)
      end
    end

    def self.can_issue?(inviter_membership:, organization:, role_key:)
      new(inviter_membership: inviter_membership).issue_allowed?(organization: organization, role_key: role_key)
    end

    def self.can_manage_invitation?(inviter_membership:, invitation:)
      new(inviter_membership: inviter_membership).manage_allowed?(invitation: invitation)
    end

    def initialize(inviter_membership:)
      @inviter_membership = inviter_membership
    end

    def issue_allowed!(organization:, role_key:)
      raise Denied unless issue_allowed?(organization: organization, role_key: role_key)
    end

    def manage_allowed!(invitation:)
      raise Denied unless manage_allowed?(invitation: invitation)
    end

    def issue_allowed?(organization:, role_key:)
      return false unless active_inviter?
      return false unless organization.active?
      return false unless Authorization::EffectivePermissions.allowed?(
        membership: @inviter_membership,
        permission_key: "team.invite"
      )

      if organization.ant_marine?
        staff_issue_to_ant_marine?(organization: organization, role_key: role_key)
      elsif organization.client?
        staff_issue_to_client_org?(organization: organization, role_key: role_key) ||
          client_issue_within_org?(organization: organization, role_key: role_key)
      else
        false
      end
    end

    def manage_allowed?(invitation:)
      return false unless active_inviter?

      issue_allowed?(organization: invitation.organization, role_key: invitation.role_key) &&
        visible_invitation_scope.exists?(invitation.id)
    end

    def visible_invitation_scope
      if @inviter_membership.staff_domain? && staff_issuer?
        if @inviter_membership.organization.ant_marine?
          ant_marine = Organization.ant_marine!
          Invitation.where(organization_id: [ ant_marine.id, *Organization.active.where(kind: "client").select(:id) ])
        else
          Invitation.none
        end
      elsif @inviter_membership.client_domain? && client_issuer?
        Invitation.where(organization_id: @inviter_membership.organization_id)
      else
        Invitation.none
      end
    end

    def allowed_roles_for(organization:)
      return [] unless active_inviter?

      if organization.ant_marine?
        staff_targets_for_inviter
      elsif organization.client?
        client_targets_for_inviter(organization: organization)
      else
        []
      end
    end

    private

      def active_inviter?
        @inviter_membership&.portal_access? && @inviter_membership.status == "active"
      end

      def staff_issuer?
        STAFF_ISSUER_ROLES.include?(@inviter_membership.role_key)
      end

      def client_issuer?
        CLIENT_ISSUER_ROLES.include?(@inviter_membership.role_key)
      end

      def staff_issue_to_ant_marine?(organization:, role_key:)
        return false unless organization.ant_marine?
        return false unless @inviter_membership.staff_domain?
        return false unless @inviter_membership.organization_id == organization.id
        return false unless staff_issuer?
        return false unless RoleKeys.staff?(role_key)

        staff_targets_for_inviter.include?(role_key)
      end

      def staff_issue_to_client_org?(organization:, role_key:)
        return false unless organization.client?
        return false unless @inviter_membership.staff_domain?
        return false unless @inviter_membership.organization.ant_marine?
        return false unless staff_issuer?
        return false unless RoleKeys.client?(role_key)

        CLIENT_INVITE_TARGETS.include?(role_key)
      end

      def client_issue_within_org?(organization:, role_key:)
        return false unless organization.client?
        return false unless @inviter_membership.client_domain?
        return false unless @inviter_membership.organization_id == organization.id
        return false unless client_issuer?
        return false unless RoleKeys.client?(role_key)

        CLIENT_INVITE_TARGETS.include?(role_key)
      end

      def staff_targets_for_inviter
        case @inviter_membership.role_key
        when "staff.super_administrator"
          SUPER_ADMIN_STAFF_TARGETS
        when "staff.operations_manager"
          OPS_MANAGER_STAFF_TARGETS
        else
          []
        end
      end

      def client_targets_for_inviter(organization:)
        return [] unless @inviter_membership.organization_id == organization.id

        if staff_issuer? && @inviter_membership.organization.ant_marine?
          CLIENT_INVITE_TARGETS
        elsif client_issuer?
          CLIENT_INVITE_TARGETS
        else
          []
        end
      end
  end
end
