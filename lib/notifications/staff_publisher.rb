# frozen_string_literal: true

module Notifications
  # Creates in-app staff notifications from audit events that have just been recorded,
  # inside the same transaction. One notification per recipient per event (unique key),
  # never to the person who acted, and never by email.
  module StaffPublisher
    UNIQUE_INDEX = :index_staff_notifications_on_recipient_and_dedupe_key

    module_function

    def new_enquiry(inquiry:, audit_event:)
      recipients = active_staff(inquiry.organization).select do |membership|
        permissions = Authorization::EffectivePermissions.new(membership)
        permissions.allowed?("inquiries.view_all") && permissions.allowed?("inquiries.qualify")
      end
      publish(recipients, kind: "new_enquiry", inquiry: inquiry, audit_event: audit_event,
                          title: "New enquiry #{inquiry.reference_number} from #{inquiry.company_name}")
    end

    def assignment_changed(inquiry:, assignee:, previous:, actor:, audit_event:)
      if assignee && assignee.id != actor.id
        publish([ assignee ], kind: "enquiry_assigned", inquiry: inquiry, audit_event: audit_event,
                              title: "You are now responsible for #{inquiry.reference_number} (#{inquiry.company_name})")
      end
      return unless previous && previous.id != actor.id && previous.id != assignee&.id

      publish([ previous ], kind: "enquiry_reassigned_away", inquiry: inquiry, audit_event: audit_event,
                            title: "#{inquiry.reference_number} (#{inquiry.company_name}) is no longer assigned to you")
    end

    def clarification_answered(inquiry:, actor:, audit_event:)
      assignee = inquiry.assigned_membership
      return unless assignee && assignee.id != actor.id

      publish([ assignee ], kind: "clarification_answered", inquiry: inquiry, audit_event: audit_event,
                            title: "The client’s answer for #{inquiry.reference_number} has been recorded")
    end

    def active_staff(organization)
      Membership.active.where(organization: organization).joins(:user).where(users: { status: "active" })
                .includes(:organization).select(&:staff_domain?)
    end

    def publish(recipients, kind:, inquiry:, audit_event:, title:)
      raise ArgumentError, "#{kind} is not an in-app event" unless Events.fetch(kind)[:channel] == "in_app"

      now = Time.current
      rows = recipients.uniq(&:id).filter_map do |membership|
        next unless membership.status == "active" && membership.organization_id == inquiry.organization_id

        {
          organization_id: inquiry.organization_id,
          recipient_membership_id: membership.id,
          audit_event_id: audit_event.id,
          kind: kind,
          subject_type: "ServiceInquiry",
          subject_id: inquiry.id,
          title: title.truncate(200),
          dedupe_key: "#{kind}:#{audit_event.id}",
          created_at: now
        }
      end
      StaffNotification.insert_all(rows, unique_by: UNIQUE_INDEX) if rows.any?
      rows.size
    end
  end
end
