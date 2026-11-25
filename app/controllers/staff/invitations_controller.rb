# frozen_string_literal: true

module Staff
  class InvitationsController < BaseController
    PER_PAGE = 6

    before_action :require_staff_invitation_access!
    before_action :set_ant_marine_organization

    def index
      @policy = ::Invitations::Policy.new(inviter_membership: Current.membership)
      base = @policy.visible_invitation_scope.where(organization: @organization)
      @filter = params[:show] == "all" ? "all" : "active"
      @active_count = base.active.count
      scoped = @filter == "active" ? base.active : base
      @pagination = Pagination.new(scoped.order(created_at: :desc), page: params[:page], per_page: PER_PAGE)
      @invitations = @pagination.records
      @allowed_roles = @policy.allowed_roles_for(organization: @organization)
    end

    def create
      result = ::Invitations::Issue.call(
        inviter_membership: Current.membership,
        organization: @organization,
        email: params.require(:email),
        role_key: params.require(:role_key)
      )

      notice = "Invitation sent to #{result.invitation.email}."
      if Rails.env.local?
        notice += " Development link: #{invitation_url(token: result.raw_token)}"
      end
      redirect_to staff_invitations_path, notice: notice
    rescue ::Invitations::Policy::Denied
      redirect_to staff_invitations_path, alert: "You are not allowed to send that invitation."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to staff_invitations_path, alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      invitation = Invitation.find(params[:id])
      ::Invitations::Revoke.call(inviter_membership: Current.membership, invitation: invitation)
      redirect_to staff_invitations_path, notice: "Invitation cancelled."
    rescue ::Invitations::Policy::Denied
      redirect_to staff_invitations_path, alert: "You are not allowed to cancel that invitation."
    end

    def resend
      invitation = Invitation.find(params[:id])
      result = ::Invitations::Resend.call(inviter_membership: Current.membership, invitation: invitation)
      notice = "Invitation resent to #{result.invitation.email}."
      if Rails.env.local?
        notice += " Development link: #{invitation_url(token: result.raw_token)}"
      end
      redirect_to staff_invitations_path, notice: notice
    rescue ::Invitations::Policy::Denied
      redirect_to staff_invitations_path, alert: "You are not allowed to resend that invitation."
    rescue ::Invitations::Resend::Error => e
      redirect_to staff_invitations_path, alert: e.message
    end

    private

      def require_staff_invitation_access!
        return if Authorization::EffectivePermissions.allowed?(
          membership: Current.membership,
          permission_key: "team.invite"
        )

        redirect_to staff_root_path, alert: "You do not have permission to manage invitations."
      end

      def set_ant_marine_organization
        @organization = Organization.ant_marine!
      end
  end
end
