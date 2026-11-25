# frozen_string_literal: true

module Clients
  # Explicit enquiry-led portal onboarding: link or create a client organisation,
  # prepare a secure invitation, and audit every association. Does not grant
  # commercial acceptance workflows (F4-04A hard stop).
  class OnboardFromEnquiry
    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    Result = Data.define(:organization, :invitation, :raw_token, :inquiry)

    ELIGIBLE_STATUSES = %w[qualified].freeze

    def self.call(actor_membership:, inquiry:, params:)
      new(actor_membership: actor_membership).call(inquiry: inquiry, params: params)
    end

    def initialize(actor_membership:)
      @actor = actor_membership
    end

    def call(inquiry:, params:)
      authorize!(inquiry)
      raise InvalidState, "Set up client access only for a qualified enquiry." unless inquiry.current_status.in?(ELIGIBLE_STATUSES)

      data = params.to_h.stringify_keys
      confirmation = ActiveModel::Type::Boolean.new.cast(data["confirm_organization"])
      raise Error, "Confirm that this is the correct organisation for the enquiry." unless confirmation

      organization = nil
      invitation = nil
      raw_token = nil

      ServiceInquiry.transaction do
        inquiry.lock!
        raise InvalidState, "This enquiry changed. Refresh and try again." unless inquiry.current_status.in?(ELIGIBLE_STATUSES)

        organization = resolve_organization!(data)
        link_inquiry!(inquiry, organization, data["link_reason"])

        email = data["contact_email"].to_s.strip.downcase.presence || inquiry.contact_email
        role_key = data["role_key"].presence || "client.client_member"
        raise Error, "Choose a permitted portal access level." unless RoleKeys.client?(role_key)

        refuse_existing_user_conflicts!(email, organization)

        issued = Invitations::Issue.call(
          inviter_membership: @actor,
          organization: organization,
          email: email,
          role_key: role_key
        )
        invitation = issued.invitation
        raw_token = issued.raw_token
      end

      AuditEvent.record!(
        organization: Organization.ant_marine!,
        actor_membership: @actor,
        event_type: "client_onboarding.completed",
        subject: inquiry,
        metadata: {
          "client_organization_id" => organization.id,
          "invitation_id" => invitation.id,
          "role_key" => invitation.role_key,
          "email" => invitation.email
        }
      )

      Result.new(organization: organization, invitation: invitation, raw_token: raw_token, inquiry: inquiry.reload)
    end

    private

      def authorize!(inquiry)
        unless @actor&.staff_domain? && @actor.portal_access? &&
               Authorization::EffectivePermissions.allowed?(membership: @actor, permission_key: "inquiries.qualify") &&
               Authorization::EffectivePermissions.allowed?(membership: @actor, permission_key: "team.invite") &&
               inquiry.organization_id == @actor.organization_id
          raise Denied, "You are not allowed to set up client access for this enquiry."
        end
      end

      def resolve_organization!(data)
        mode = data["organization_mode"].to_s
        case mode
        when "existing"
          org = Quote.assignable_client_organizations(@actor.organization).find_by(id: data["client_organization_id"].to_s)
          raise Error, "Choose an existing client organisation." unless org

          org
        when "create"
          Clients::CreateOrganization.call(
            actor_membership: @actor,
            attributes: {
              name: data["organization_name"].presence || inquiry_company_fallback(data),
              trading_name: data["trading_name"],
              business_email: data["contact_email"],
              business_phone: data["contact_phone"],
              address: data["address"],
              country: data["country"],
              primary_contact_name: data["contact_name"],
              primary_contact_email: data["contact_email"],
              primary_contact_phone: data["contact_phone"]
            }
          ).organization
        else
          raise Error, "Choose whether to use an existing organisation or create a new one."
        end
      end

      def inquiry_company_fallback(data)
        data["organization_name"].presence || "Client organisation"
      end

      def link_inquiry!(inquiry, organization, reason)
        previous = inquiry.client_organization_id
        inquiry.update_columns(client_organization_id: organization.id, updated_at: Time.current)

        AuditEvent.record!(
          organization: Organization.ant_marine!,
          actor_membership: @actor,
          event_type: "enquiry.linked_to_client_organization",
          subject: inquiry,
          metadata: {
            "client_organization_id" => organization.id,
            "previous_client_organization_id" => previous,
            "reason" => reason.to_s.presence || "Confirmed during client access setup"
          }
        )
      end

      def refuse_existing_user_conflicts!(email, organization)
        user = User.find_by(email: email)
        return if user.nil?

        if user.memberships.joins(:organization).where(organizations: { kind: "ant_marine" }, status: Membership::PORTAL_ACCESS_STATUSES).exists?
          raise Error, "This email belongs to an ANT Marine staff account. Invite a different client contact."
        end

        existing = user.memberships.find_by(organization_id: organization.id)
        if existing&.status == "active"
          raise Error, "This person already has active access to this organisation. Use membership management instead of a new invitation."
        end
      end
  end
end
