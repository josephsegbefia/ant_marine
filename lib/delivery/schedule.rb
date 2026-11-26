# frozen_string_literal: true

module Delivery
  module Schedule
    class Error < StandardError; end
    class Denied < Error; end
    class Conflict < Error; end

    module_function

    def propose!(actor:, project:, attrs:, conflict_override: false, conflict_reason: nil)
      assert_manage!(actor, project)
      raise Error, "Scheduling needs an open project." unless project.open?

      starts_at = parse_time(attrs[:starts_at])
      ends_at = parse_time(attrs[:ends_at])
      raise Error, "Choose a start and end time." if starts_at.blank? || ends_at.blank?
      raise Error, "The end time must be after the start time." unless starts_at < ends_at

      responsible_id = attrs[:responsible_membership_id].presence
      if responsible_id
        membership = Membership.find(responsible_id)
        raise Error, "Responsible staff must be on the project team." unless project.assigned?(membership.user) ||
          membership.id == project.coordinator_membership_id
      end

      conflicts = overlapping(responsible_id, starts_at, ends_at)
      if conflicts.exists?
        unless ActiveModel::Type::Boolean.new.cast(conflict_override) && conflict_reason.to_s.strip.present?
          raise Conflict, "That person already has another activity in this time range."
        end
      end

      event = project.schedule_events.create!(
        title: attrs.fetch(:title).to_s.strip,
        activity_type: attrs[:activity_type].presence || "site_work",
        confirmation_state: "proposed",
        location: attrs[:location].to_s.strip.presence,
        starts_at: starts_at,
        ends_at: ends_at,
        responsible_membership_id: responsible_id,
        internal_notes: attrs[:internal_notes].to_s.strip.presence,
        created_by_membership: actor,
        conflict_override: conflicts.exists?,
        conflict_override_reason: conflicts.exists? ? conflict_reason.to_s.strip : nil
      )

      AuditEvent.record!(
        organization: project.operating_organization,
        actor_membership: actor,
        event_type: "project.schedule.proposed",
        subject: project,
        metadata: { "schedule_event_id" => event.id, "starts_at" => event.starts_at.iso8601 }
      )
      event
    end

    def confirm!(actor:, event:)
      assert_manage!(actor, event.project)
      raise Error, "Only proposed or rescheduled activities can be confirmed." unless event.confirmation_state.in?(%w[proposed rescheduled])

      event.update!(
        confirmation_state: "confirmed",
        confirmed_by_membership: actor,
        confirmed_at: Time.current
      )
      audit = AuditEvent.record!(
        organization: event.project.operating_organization,
        actor_membership: actor,
        event_type: "project.schedule.confirmed",
        subject: event.project,
        metadata: { "schedule_event_id" => event.id }
      )
      Notifications::StaffPublisher.schedule_confirmed(project: event.project, event: event, audit_event: audit)
      event
    end

    def cancel!(actor:, event:, reason:)
      assert_manage!(actor, event.project)
      raise Error, "Add a reason for cancelling this activity." if reason.to_s.strip.blank?

      event.update!(confirmation_state: "cancelled", cancellation_reason: reason.to_s.strip)
      audit = AuditEvent.record!(
        organization: event.project.operating_organization,
        actor_membership: actor,
        event_type: "project.schedule.cancelled",
        subject: event.project,
        metadata: { "schedule_event_id" => event.id, "reason" => reason.to_s.strip }
      )
      Notifications::StaffPublisher.schedule_cancelled(project: event.project, event: event, audit_event: audit)
      event
    end

    def overlapping(responsible_id, starts_at, ends_at, excluding_id: nil)
      return ScheduleEvent.none if responsible_id.blank?

      scope = ScheduleEvent.where(responsible_membership_id: responsible_id)
                           .where.not(confirmation_state: "cancelled")
                           .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
      excluding_id ? scope.where.not(id: excluding_id) : scope
    end

    def assert_manage!(actor, project)
      perms = Authorization::EffectivePermissions.new(actor)
      ok = perms.allowed?("projects.manage") || perms.allowed?("bookings.confirm") ||
           (perms.allowed?("assignments.participate") && project.assigned?(actor.user))
      raise Denied, "You are not allowed to schedule this project." unless ok
    end

    def parse_time(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return if value.blank?

      Time.zone.parse(value.to_s)
    end
  end
end
