# frozen_string_literal: true

module Invitations
  class Accept
    Result = Data.define(:user, :membership, :invitation)

    class Error < StandardError
      attr_reader :message

      def initialize(message)
        @message = message
        super(message)
      end
    end

    def self.call(invitation:, actor_user: nil, new_user_params: nil)
      new.call(invitation: invitation, actor_user: actor_user, new_user_params: new_user_params)
    end

    def call(invitation:, actor_user: nil, new_user_params: nil)
      raise Error, "This invitation is no longer valid." unless invitation.usable?

      user = resolve_user!(invitation: invitation, actor_user: actor_user, new_user_params: new_user_params)

      membership = nil

      Invitation.transaction do
        invitation.lock!
        invitation.reload
        raise Error, "This invitation is no longer valid." unless invitation.usable?

        if Membership.exists?(user_id: user.id, organization_id: invitation.organization_id)
          active = Membership.find_by!(user_id: user.id, organization_id: invitation.organization_id)
          if active.status == "active"
            raise Error, "You already belong to this organisation."
          end
        end

        rows = Invitation.where(id: invitation.id, status: "pending").update_all(
          status: "accepted",
          accepted_by_user_id: user.id,
          accepted_at: Time.current,
          updated_at: Time.current
        )
        raise Error, "This invitation could not be completed. Please try again." unless rows == 1

        invitation.reload

        membership = Membership.find_or_initialize_by(user: user, organization: invitation.organization)
        if membership.persisted? && membership.status == "active"
          raise Error, "You already belong to this organisation."
        end

        membership.assign_attributes(
          role_key: invitation.role_key,
          status: "active",
          accepted_at: Time.current,
          invited_at: membership.invited_at || invitation.created_at
        )
        membership.save!

        user.update!(email_verified_at: Time.current) if user.email_verified_at.nil?
      end

      InvitationAudit.accepted(invitation: invitation, user: user)
      InvitationAudit.membership_created(invitation: invitation, user: user, membership: membership)

      Result.new(user: user, membership: membership, invitation: invitation)
    end

    private

      def resolve_user!(invitation:, actor_user:, new_user_params:)
        existing = User.find_by(email: invitation.email)

        if existing
          unless actor_user
            raise Error, "Please sign in with the invited email address to continue."
          end
          unless actor_user.id == existing.id
            raise Error, "Sign in with #{invitation.email} to accept this invitation."
          end
          unless actor_user.active?
            raise Error, "This account cannot accept invitations right now."
          end

          existing
        else
          raise Error, "Please complete the account setup form." if new_user_params.blank?

          user = User.new(
            email: invitation.email,
            full_name: new_user_params[:full_name],
            password: new_user_params[:password],
            password_confirmation: new_user_params[:password_confirmation],
            status: "active"
          )
          unless user.save(context: :invitation_setup)
            raise Error, user.errors.full_messages.to_sentence
          end
          user
        end
      end
  end
end
