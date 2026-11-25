# frozen_string_literal: true

module Clients
  class ManageContact
    class Error < StandardError; end
    class Denied < Error; end

    def self.create!(actor_membership:, organization:, attributes:)
      new(actor_membership: actor_membership).create!(organization: organization, attributes: attributes)
    end

    def self.archive!(actor_membership:, contact:)
      new(actor_membership: actor_membership).archive!(contact: contact)
    end

    def initialize(actor_membership:)
      @actor = actor_membership
    end

    def create!(organization:, attributes:)
      authorize!(organization)
      contact = organization.client_contacts.create!(
        normalize(attributes).merge(
          status: "active",
          created_by_membership: @actor
        )
      )
      AuditEvent.record!(
        organization: Organization.ant_marine!,
        actor_membership: @actor,
        event_type: "client_contact.created",
        subject: contact,
        metadata: {
          "client_organization_id" => organization.id,
          "email" => contact.email
        }
      )
      contact
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.record.errors.full_messages.to_sentence
    end

    def archive!(contact:)
      authorize!(contact.organization)
      contact.update!(status: "archived")
      AuditEvent.record!(
        organization: Organization.ant_marine!,
        actor_membership: @actor,
        event_type: "client_contact.archived",
        subject: contact,
        metadata: { "client_organization_id" => contact.organization_id }
      )
      contact
    end

    private

      def authorize!(organization)
        unless @actor&.staff_domain? && @actor.portal_access? &&
               Authorization::EffectivePermissions.allowed?(membership: @actor, permission_key: "inquiries.qualify") &&
               organization.client?
          raise Denied, "You are not allowed to manage contacts for this organisation."
        end
      end

      def normalize(attributes)
        raw = attributes.to_h.stringify_keys
        {
          full_name: raw["full_name"].to_s.squish,
          email: raw["email"].to_s.strip.downcase.presence,
          phone: raw["phone"].to_s.squish.presence,
          job_title: raw["job_title"].to_s.squish.presence,
          notes: raw["notes"].to_s.strip.presence
        }
      end
  end
end
