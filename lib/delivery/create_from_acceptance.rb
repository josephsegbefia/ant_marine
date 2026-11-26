# frozen_string_literal: true

module Delivery
  # Explicit staff initiation of a project from an eligible accepted commercial offer.
  # Never called automatically from QuoteDecision. Simulation only until live policy is approved.
  class CreateFromAcceptance
    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end
    class Conflict < Error; end

    Result = Data.define(:project, :created)

    DEFAULT_MILESTONES = [
      { kind: "project_initiated", title: "Project initiated", position: 0 },
      { kind: "planning", title: "Planning completed", position: 1 },
      { kind: "mobilization", title: "Mobilization", position: 2 },
      { kind: "site_work", title: "Site work", position: 3 },
      { kind: "technical_review", title: "Technical review", position: 4, counts_toward_progress: false },
      { kind: "report_release", title: "Report release", position: 5, counts_toward_progress: false },
      { kind: "project_completion", title: "Project completion", position: 6 }
    ].freeze

    def self.available?
      !Rails.env.production?
    end

    def self.call(membership:, quote_response:, attributes: {}, confirmation: false)
      new(membership: membership).call(
        quote_response: quote_response,
        attributes: attributes,
        confirmation: confirmation
      )
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(quote_response:, attributes: {}, confirmation: false)
      raise Denied, "Project creation from simulated acceptance is not available in production." unless self.class.available?
      raise Denied, "Only authorised ANT Marine staff can create projects." unless staff_actor?
      raise Denied, "You need permission to create projects." unless permission_allowed?("projects.create")
      raise Error, "Confirm project creation before continuing." unless ActiveModel::Type::Boolean.new.cast(confirmation)

      attrs = attributes.to_h.symbolize_keys

      Project.transaction do
        response = QuoteResponse.lock.find(quote_response.id)
        raise InvalidState, "Only an accepted offer can start a project." unless response.accepted?
        raise InvalidState, "Only simulated acceptances can start projects until live policy is approved." unless response.simulated?

        existing = Project.find_by(quote_response_id: response.id)
        return Result.new(project: existing, created: false) if existing

        release = QuotePortalRelease.lock.find(response.quote_portal_release_id)
        revision = QuoteRevision.lock.find(response.quote_revision_id)
        quote = Quote.lock.find(response.quote_id)
        client_org = Organization.lock.find(response.client_organization_id)

        validate_commercial_source!(response, release, revision, quote, client_org)

        title = attrs[:title].to_s.strip.presence || revision.title.presence || quote.reference_number
        project = Project.create!(
          reference_number: Reference.generate!,
          title: title,
          operating_organization: Organization.ant_marine!,
          client_organization: client_org,
          service_id: quote.service_id,
          service_inquiry_id: quote.service_inquiry_id,
          quote: quote,
          quote_revision: revision,
          quote_response: response,
          quote_portal_release: release,
          created_by_membership: @membership,
          coordinator_membership_id: attrs[:coordinator_membership_id].presence,
          internal_status: "planning",
          client_status: "planning",
          mode: "simulated",
          location: attrs[:location].to_s.strip.presence,
          vessel_name: attrs[:vessel_name].to_s.strip.presence,
          vessel_identifier: attrs[:vessel_identifier].to_s.strip.presence,
          operational_description: attrs[:operational_description].to_s.strip.presence || revision.scope_description,
          internal_notes: attrs[:internal_notes].to_s.strip.presence,
          proposed_start_on: attrs[:proposed_start_on].presence,
          target_completion_on: attrs[:target_completion_on].presence,
          commercial_snapshot: commercial_snapshot(quote, revision, response, release)
        )

        seed_milestones!(project)
        assign_coordinator!(project, attrs[:coordinator_membership_id]) if attrs[:coordinator_membership_id].present?

        status_event = ProjectStatusEvent.create!(
          project: project,
          from_status: nil,
          to_status: "planning",
          actor_membership: @membership,
          reason: "Project created from accepted offer",
          occurred_at: Time.current
        )

        audit = AuditEvent.record!(
          organization: project.operating_organization,
          actor_membership: @membership,
          event_type: "project.created",
          subject: project,
          metadata: {
            "reference_number" => project.reference_number,
            "quote_reference" => quote.reference_number,
            "quote_revision_id" => revision.id,
            "quote_response_id" => response.id,
            "mode" => project.mode,
            "client_organization_id" => client_org.id,
            "project_status_event_id" => status_event.id
          }
        )

        Notifications::StaffPublisher.project_created(project: project, audit_event: audit)

        Result.new(project: project, created: true)
      end
    rescue ActiveRecord::RecordNotUnique
      existing = Project.find_by(quote_response_id: quote_response.id)
      raise Conflict, "A project already exists for this acceptance." unless existing

      Result.new(project: existing, created: false)
    end

    private

      def staff_actor?
        @membership&.status == "active" && @membership.staff_domain? &&
          @membership.organization_id == Organization.ant_marine!.id
      end

      def permission_allowed?(key)
        Authorization::EffectivePermissions.new(@membership).allowed?(key)
      end

      def validate_commercial_source!(response, release, revision, quote, client_org)
        raise InvalidState, "The client organisation is not active." unless client_org.status == "active" && client_org.kind == "client"
        raise InvalidState, "Acceptance must match the portal release." unless response.quote_portal_release_id == release.id
        raise InvalidState, "Acceptance must match the frozen quotation version." unless response.quote_revision_id == revision.id
        raise InvalidState, "Acceptance must match the quotation." unless response.quote_id == quote.id
        raise InvalidState, "Client organisation does not match the acceptance." unless response.client_organization_id == client_org.id
        raise InvalidState, "Portal release is not active." unless release.active?
        raise InvalidState, "Portal release must be simulated until live release is approved." unless release.simulated?
        raise InvalidState, "Portal release belongs to a different client." unless release.client_organization_id == client_org.id
        raise InvalidState, "Only a frozen accepted version can start a project." unless revision.frozen_at.present?
        raise InvalidState, "Quotation version must match the release." unless release.quote_revision_id == revision.id
      end

      def commercial_snapshot(quote, revision, response, release)
        {
          "quote_reference" => quote.reference_number,
          "version_number" => revision.version_number,
          "quote_revision_id" => revision.id,
          "quote_response_id" => response.id,
          "quote_portal_release_id" => release.id,
          "accepted_at" => response.confirmed_at&.iso8601,
          "currency" => revision.currency,
          "total_cents" => revision.total_cents,
          "title" => revision.title,
          "scope_description" => revision.scope_description,
          "deliverables" => revision.deliverables,
          "exclusions" => revision.exclusions,
          "payment_terms" => revision.payment_terms,
          "valid_until" => revision.valid_until&.iso8601,
          "mode" => response.mode
        }
      end

      def seed_milestones!(project)
        DEFAULT_MILESTONES.each do |row|
          project.project_milestones.create!(
            title: row[:title],
            kind: row[:kind],
            position: row[:position],
            status: row[:kind] == "project_initiated" ? "completed" : "pending",
            completed_at: row[:kind] == "project_initiated" ? Time.current : nil,
            completed_by_membership: row[:kind] == "project_initiated" ? @membership : nil,
            counts_toward_progress: row.fetch(:counts_toward_progress, true)
          )
        end
      end

      def assign_coordinator!(project, membership_id)
        target = Membership.find(membership_id)
        Delivery::Assign.call(
          actor_membership: @membership,
          project: project,
          membership: target,
          assignment_kind: "coordinator",
          reason: "Initial project coordinator"
        )
        project.update!(coordinator_membership: target)
      end
  end
end
