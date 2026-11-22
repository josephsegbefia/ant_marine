# frozen_string_literal: true

module Invitations
  class Issue
    Result = Data.define(:invitation, :raw_token)

    class Error < StandardError; end

    def self.call(inviter_membership:, organization:, email:, role_key:)
      new(inviter_membership: inviter_membership).call(organization: organization, email: email, role_key: role_key)
    end

    def initialize(inviter_membership:)
      @inviter_membership = inviter_membership
      @policy = Policy.new(inviter_membership: inviter_membership)
    end

    def call(organization:, email:, role_key:)
      @policy.issue_allowed!(organization: organization, role_key: role_key)

      raw_token = nil
      invitation = nil

      Invitation.transaction do
        revoke_pending_duplicates!(organization: organization, email: email)

        raw_token, digest = Token.generate
        invitation = Invitation.create!(
          organization: organization,
          email: email,
          role_key: role_key,
          token_digest: digest,
          status: "pending",
          expires_at: Invitation::DEFAULT_EXPIRY.from_now,
          invited_by_membership: @inviter_membership
        )
      end

      InvitationsMailer.invite(invitation, raw_token).deliver_later
      InvitationAudit.issued(invitation: invitation, actor_membership: @inviter_membership)

      Result.new(invitation: invitation, raw_token: raw_token)
    rescue Policy::Denied => e
      InvitationAudit.denied(
        actor_membership: @inviter_membership,
        organization: organization,
        metadata: { "reason" => "issue_denied", "role_key" => role_key }
      )
      raise e
    end

    private

      def revoke_pending_duplicates!(organization:, email:)
        normalized = email.to_s.strip.downcase
        Invitation.pending.where(organization_id: organization.id, email: normalized).find_each(&:revoke!)
      end
  end
end
