# frozen_string_literal: true

module Clients
  class UpdateOrganization
    class Error < StandardError; end
    class Denied < Error; end

    Result = Data.define(:organization)

    def self.call(actor_membership:, organization:, attributes:)
      new(actor_membership: actor_membership).call(organization: organization, attributes: attributes)
    end

    def initialize(actor_membership:)
      @actor = actor_membership
    end

    def call(organization:, attributes:)
      authorize!(organization)
      raise Error, "Only client organisations can be edited here." unless organization.client?

      attrs = attributes.to_h.stringify_keys
      name = attrs["name"].to_s.squish.presence || organization.name
      profile = (organization.profile || {}).stringify_keys
      CreateOrganization::PROFILE_KEYS.each do |key|
        next unless attrs.key?(key)

        profile[key] = attrs[key].to_s.squish.presence
      end

      organization.update!(name: name, profile: profile.compact)

      AuditEvent.record!(
        organization: Organization.ant_marine!,
        actor_membership: @actor,
        event_type: "client_organization.updated",
        subject: organization,
        metadata: { "name" => organization.name }
      )

      Result.new(organization: organization)
    end

    private

      def authorize!(organization)
        unless @actor&.staff_domain? && @actor.portal_access? &&
               Authorization::EffectivePermissions.allowed?(membership: @actor, permission_key: "inquiries.qualify") &&
               organization.client?
          raise Denied, "You are not allowed to edit this organisation."
        end
      end
  end
end
