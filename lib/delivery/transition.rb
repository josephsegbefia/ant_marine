# frozen_string_literal: true

module Delivery
  # Explicit project lifecycle transitions — no generic status writes.
  class Transition
    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    # action => { from:, permission:, client_map handled by Project::CLIENT_STATUS_MAP }
    RULES = {
      mark_scheduled: {
        from: %w[planning],
        to: "scheduled",
        permission: "projects.manage"
      },
      start_work: {
        from: %w[planning scheduled],
        to: "in_progress",
        permission: "projects.manage"
      },
      enter_technical_review: {
        from: %w[in_progress],
        to: "technical_review",
        permission: "projects.manage",
        gated: :technical_review
      },
      mark_report_ready: {
        from: %w[technical_review],
        to: "report_ready",
        permission: "projects.manage",
        gated: :report_release
      },
      complete: {
        from: %w[in_progress technical_review report_ready],
        to: "completed",
        permission: "projects.manage"
      },
      close: {
        from: %w[completed],
        to: "closed",
        permission: "projects.manage"
      },
      place_on_hold: {
        from: %w[planning scheduled in_progress technical_review report_ready],
        to: "on_hold",
        permission: "projects.manage",
        require_reason: true
      },
      resume: {
        from: %w[on_hold],
        to: "planning",
        permission: "projects.manage",
        require_reason: true
      },
      cancel: {
        from: %w[planning scheduled in_progress technical_review report_ready on_hold],
        to: "cancelled",
        permission: "projects.manage",
        require_reason: true
      }
    }.freeze

    def self.apply!(project:, action:, membership:, reason: nil)
      new(membership: membership).apply!(project: project, action: action, reason: reason)
    end

    def self.available_actions(project)
      RULES.filter_map do |action, rule|
        next unless rule[:from].include?(project.internal_status)
        next if rule[:gated] # evidence-gated transitions stay hidden until F4-07

        action
      end
    end

    def initialize(membership:)
      @membership = membership
    end

    def apply!(project:, action:, reason: nil)
      rule = RULES[action.to_sym]
      raise InvalidState, "That project action is not recognised." unless rule
      raise Denied, "You need permission to manage this project." unless allowed?(rule[:permission])
      raise Denied, "Sign in as active ANT Marine staff." unless staff_actor?
      raise InvalidState, "That action is not available from the current project status." unless rule[:from].include?(project.internal_status)

      if rule[:require_reason] && reason.to_s.strip.blank?
        raise Error, "Add a short reason before continuing."
      end

      if rule[:gated]
        raise InvalidState, "This step needs technical evidence from a later module (F4-07)."
      end

      Project.transaction do
        locked = Project.lock.find(project.id)
        raise InvalidState, "That action is not available from the current project status." unless rule[:from].include?(locked.internal_status)

        from = locked.internal_status
        locked.update!(internal_status: rule[:to], client_status: Project::CLIENT_STATUS_MAP.fetch(rule[:to]))

        event = ProjectStatusEvent.create!(
          project: locked,
          from_status: from,
          to_status: rule[:to],
          actor_membership: @membership,
          reason: reason.to_s.strip.presence,
          occurred_at: Time.current
        )

        AuditEvent.record!(
          organization: locked.operating_organization,
          actor_membership: @membership,
          event_type: "project.status.#{action}",
          subject: locked,
          metadata: {
            "from" => from,
            "to" => rule[:to],
            "reason" => reason.to_s.strip.presence,
            "project_status_event_id" => event.id,
            "mode" => locked.mode
          }
        )

        locked
      end
    end

    private

      def staff_actor?
        @membership&.status == "active" && @membership.staff_domain?
      end

      def allowed?(key)
        Authorization::EffectivePermissions.new(@membership).allowed?(key)
      end
  end
end
