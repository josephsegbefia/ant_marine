# frozen_string_literal: true

module Intake
  # Gives responsibility for an enquiry to one active staff member of the same
  # organisation who is allowed to work on enquiries. Every change is kept as history.
  class InquiryAssignment
    ASSIGNABLE_PERMISSIONS = %w[inquiries.view_all inquiries.view_assigned].freeze

    def self.assign!(inquiry:, membership:, assignee_id:, reason:, expected_lock_version:)
      new(inquiry:, membership:).assign!(assignee_id:, reason:, expected_lock_version:)
    end

    # Active staff who may be made responsible for enquiries in this organisation.
    def self.eligible_memberships(organization)
      Membership.active.where(organization: organization).joins(:user).where(users: { status: "active" })
                .includes(:user, :organization).to_a
                .select { |candidate| eligible?(candidate, organization) }
                .sort_by { |candidate| display_name(candidate).downcase }
    end

    def self.eligible?(candidate, organization)
      return false unless candidate&.status == "active" && candidate.user&.status == "active"
      return false unless candidate.organization_id == organization.id && candidate.staff_domain?

      permissions = Authorization::EffectivePermissions.new(candidate)
      ASSIGNABLE_PERMISSIONS.any? { |key| permissions.allowed?(key) }
    end

    def self.display_name(candidate)
      candidate.user.full_name.presence || candidate.user.email
    end

    # Records a change; the caller must already hold the enquiry row lock and have authorised the actor.
    def self.record!(inquiry:, actor:, assignee:, reason:)
      previous_id = inquiry.assigned_membership_id
      inquiry.update!(assigned_membership: assignee)
      entry = inquiry.assignments.create!(
        previous_membership_id: previous_id,
        new_membership: assignee,
        actor_membership: actor,
        reason: reason
      )
      event_type = if assignee.nil? then "service_inquiry.unassigned"
      elsif previous_id.nil? then "service_inquiry.assigned"
      else "service_inquiry.reassigned"
      end
      event = AuditEvent.record!(
        event_type: event_type,
        organization: inquiry.organization,
        actor_membership: actor,
        subject: inquiry,
        metadata: {
          reference_number: inquiry.reference_number,
          assignment_id: entry.id,
          previous_membership_id: previous_id,
          new_membership_id: assignee&.id,
          reason: reason
        }.compact
      )
      previous = previous_id && Membership.find_by(id: previous_id)
      Notifications::StaffPublisher.assignment_changed(inquiry: inquiry, assignee: assignee, previous: previous,
                                                       actor: actor, audit_event: event)
      entry
    end

    def initialize(inquiry:, membership:)
      @inquiry = inquiry
      @membership = membership
    end

    def assign!(assignee_id:, reason:, expected_lock_version:)
      reason = TriageGuard.text(reason)
      TriageGuard.limit!(reason, ServiceInquiryAssignment::REASON_LIMIT, "reason")

      ServiceInquiry.transaction do
        @inquiry.lock!
        TriageGuard.authorize!(@inquiry, @membership, :assign?)
        TriageGuard.ensure_current!(@inquiry, expected_lock_version)
        unless @inquiry.open?
          raise InquiryTransition::InvalidTransition, "Reopen this enquiry before changing who is responsible for it."
        end

        assignee = resolve_assignee(assignee_id)
        if assignee&.id == @inquiry.assigned_membership_id
          raise InquiryTransition::InvalidTransition, "That person is already responsible for this enquiry."
        end
        if @inquiry.assigned_membership_id.present? && reason.blank?
          raise InquiryTransition::InvalidTransition, "Explain why responsibility is changing."
        end

        self.class.record!(inquiry: @inquiry, actor: @membership, assignee: assignee, reason: reason)
      end
    end

    private

      def resolve_assignee(assignee_id)
        return nil if assignee_id.blank?

        candidate = Membership.includes(:user, :organization).find_by(id: assignee_id.to_s)
        unless self.class.eligible?(candidate, @inquiry.organization)
          raise InquiryTransition::InvalidTransition, "Choose an active team member who can work on enquiries."
        end

        candidate
      end
  end
end
