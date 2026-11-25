# frozen_string_literal: true

module Clients
  class CreateOrganization
    class Error < StandardError; end
    class Denied < Error; end

    PROFILE_KEYS = %w[
      trading_name business_email business_phone address country website
      registration_info primary_contact_name primary_contact_email primary_contact_phone
    ].freeze

    Result = Data.define(:organization)

    def self.call(actor_membership:, attributes:)
      new(actor_membership: actor_membership).call(attributes: attributes)
    end

    def initialize(actor_membership:)
      @actor = actor_membership
    end

    def call(attributes:)
      authorize!
      attrs = normalize(attributes)

      organization = nil
      Organization.transaction do
        organization = Organization.new(
          kind: "client",
          status: "active",
          name: attrs.fetch("name"),
          slug: unique_slug(attrs.fetch("name")),
          profile: attrs.slice(*PROFILE_KEYS),
          reference_number: next_reference_number!
        )
        organization.save!
      end

      AuditEvent.record!(
        organization: Organization.ant_marine!,
        actor_membership: @actor,
        event_type: "client_organization.created",
        subject: organization,
        metadata: {
          "name" => organization.name,
          "reference_number" => organization.reference_number
        }
      )

      Result.new(organization: organization)
    end

    private

      def authorize!
        unless @actor&.staff_domain? && @actor.portal_access? &&
               Authorization::EffectivePermissions.allowed?(membership: @actor, permission_key: "inquiries.qualify")
          raise Denied, "You are not allowed to create client organisations."
        end
      end

      def normalize(attributes)
        raw = attributes.to_h.stringify_keys
        name = raw["name"].to_s.squish
        raise Error, "Enter the organisation name." if name.blank?

        PROFILE_KEYS.each_with_object("name" => name) do |key, memo|
          value = raw[key].to_s.squish.presence
          memo[key] = value if value
        end
      end

      def unique_slug(name)
        base = name.to_s.parameterize.presence || "client"
        candidate = base
        n = 2
        while Organization.exists?(slug: candidate)
          candidate = "#{base}-#{n}"
          n += 1
        end
        candidate
      end

      def next_reference_number!
        year = Time.current.year
        prefix = "CLT-#{year}-"
        connection = Organization.connection
        connection.execute(
          "SELECT pg_advisory_xact_lock(hashtext(#{connection.quote("client-org-ref:#{year}")}))"
        )
        last = Organization.where("reference_number LIKE ?", "#{prefix}%").order(:reference_number).last
        seq = last ? last.reference_number.split("-").last.to_i + 1 : 1
        format("%s%04d", prefix, seq)
      end
  end
end
