# frozen_string_literal: true

module Staff
  class HomeController < BaseController
    def show
      @greeting_name = greeting_name
      @can_invite = Authorization::EffectivePermissions.allowed?(
        membership: Current.membership,
        permission_key: "team.invite"
      )

      return unless @can_invite

      policy = ::Invitations::Policy.new(inviter_membership: Current.membership)
      ant_marine = Organization.ant_marine!
      @pending_count = policy.visible_invitation_scope
        .where(organization: ant_marine)
        .merge(Invitation.pending)
        .count
      @can_invite_clients = Organization.active.client.exists?
    end

    private

      def greeting_name
        name = Current.user.full_name.presence
        return name.split.first if name.present?

        Current.user.email.split("@").first.titleize
      end
  end
end
