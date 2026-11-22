# frozen_string_literal: true

module Staff
  class ClientInvitationsController < BaseController
    before_action :require_staff_invitation_access!

    def new
      @client_organizations = Organization.active.where(kind: "client").order(:name)
      @organization = resolve_organization
      @policy = ::Invitations::Policy.new(inviter_membership: Current.membership)
      @allowed_roles = @organization ? @policy.allowed_roles_for(organization: @organization) : []
    end

    def create
      organization = Organization.active.client.find(params.require(:organization_id))
      result = ::Invitations::Issue.call(
        inviter_membership: Current.membership,
        organization: organization,
        email: params.require(:email),
        role_key: params.require(:role_key)
      )

      notice = "Invitation sent to #{result.invitation.email}."
      if Rails.env.local?
        notice += " Development link: #{invitation_url(token: result.raw_token)}"
      end
      redirect_to staff_invitations_path, notice: notice
    rescue ::Invitations::Policy::Denied
      redirect_to new_staff_client_invitation_path, alert: "You are not allowed to send that invitation."
    rescue ActiveRecord::RecordNotFound
      redirect_to new_staff_client_invitation_path, alert: "Choose a valid client organisation."
    end

    private

      def require_staff_invitation_access!
        return if Authorization::EffectivePermissions.allowed?(
          membership: Current.membership,
          permission_key: "team.invite"
        )

        redirect_to staff_root_path, alert: "You do not have permission to manage invitations."
      end

      def resolve_organization
        return Organization.find_by(id: params[:organization_id]) if params[:organization_id].present?

        Organization.active.where(kind: "client").order(:name).first
      end
  end
end
