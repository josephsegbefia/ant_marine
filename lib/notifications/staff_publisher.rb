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

    def quote_decision(quote:, response:, audit_event:)
      kind = case response.response
      when "accepted" then "quote_accepted"
      when "declined" then "quote_declined"
      when "changes_requested" then "quote_changes_requested"
      else
        return 0
      end

      label = response.simulated? ? "simulated test decision" : "decision"
      title = case response.response
      when "accepted"
        "#{quote.reference_number} was accepted (#{label})"
      when "declined"
        "#{quote.reference_number} was declined (#{label})"
      else
        "Changes requested on #{quote.reference_number} (#{label})"
      end

      recipients = active_staff(quote.organization).select do |membership|
        permissions = Authorization::EffectivePermissions.new(membership)
        permissions.allowed?("quotes.view_all")
      end
      publish_subject(
        recipients,
        kind: kind,
        organization: quote.organization,
        subject: quote,
        audit_event: audit_event,
        title: title
      )
    end

    def project_created(project:, audit_event:)
      label = project.simulated? ? "simulated project" : "project"
      recipients = active_staff(project.operating_organization).select do |membership|
        Authorization::EffectivePermissions.new(membership).allowed?("projects.view_all")
      end
      publish_subject(
        recipients,
        kind: "project_created",
        organization: project.operating_organization,
        subject: project,
        audit_event: audit_event,
        title: "#{project.reference_number} created (#{label}) for #{project.client_organization.name}"
      )
    end

    def project_assigned(project:, assignee:, actor:, audit_event:)
      return if assignee.id == actor.id

      publish_subject(
        [ assignee ],
        kind: "project_assigned",
        organization: project.operating_organization,
        subject: project,
        audit_event: audit_event,
        title: "You were assigned to #{project.reference_number}"
      )
    end

    def project_assignment_changed(project:, previous:, actor:, audit_event:)
      return unless previous && previous.id != actor.id

      publish_subject(
        [ previous ],
        kind: "project_assignment_changed",
        organization: project.operating_organization,
        subject: project,
        audit_event: audit_event,
        title: "#{project.reference_number} is no longer assigned to you"
      )
    end

    def task_assigned(project:, task:, audit_event:)
      assignee = task.assignee_membership
      return unless assignee

      publish_subject(
        [ assignee ],
        kind: "task_assigned",
        organization: project.operating_organization,
        subject: project,
        audit_event: audit_event,
        title: "Task on #{project.reference_number}: #{task.title}"
      )
    end

    def schedule_confirmed(project:, event:, audit_event:)
      recipients = [ event.responsible_membership, project.coordinator_membership ].compact
      publish_subject(
        recipients,
        kind: "schedule_confirmed",
        organization: project.operating_organization,
        subject: project,
        audit_event: audit_event,
        title: "Schedule confirmed for #{project.reference_number}: #{event.title}"
      )
    end

    def schedule_cancelled(project:, event:, audit_event:)
      recipients = [ event.responsible_membership, project.coordinator_membership ].compact
      publish_subject(
        recipients,
        kind: "schedule_cancelled",
        organization: project.operating_organization,
        subject: project,
        audit_event: audit_event,
        title: "Schedule cancelled for #{project.reference_number}: #{event.title}"
      )
    end

    def active_staff(organization)
      Membership.active.where(organization: organization).joins(:user).where(users: { status: "active" })
                .includes(:organization).select(&:staff_domain?)
    end

    def publish(recipients, kind:, inquiry:, audit_event:, title:)
      publish_subject(
        recipients,
        kind: kind,
        organization: inquiry.organization,
        subject: inquiry,
        audit_event: audit_event,
        title: title
      )
    end

    def document_uploaded(document:, audit_event:, actor:)
      project = document.project
      recipients = delivery_staff(project).reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "document_uploaded",
        organization: project.operating_organization,
        subject: document,
        audit_event: audit_event,
        title: "New file on #{project.reference_number}: #{document.title}"
      )
    end

    def document_review_required(document:, audit_event:, actor:)
      project = document.project
      recipients = staff_with_permissions(project.operating_organization, "reports.review", "documents.manage")
                       .reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "document_review_required",
        organization: project.operating_organization,
        subject: document,
        audit_event: audit_event,
        title: "Review required on #{project.reference_number}: #{document.title}"
      )
    end

    def document_changes_requested(document:, audit_event:, actor:)
      project = document.project
      uploader = document.current_version&.uploaded_by_membership
      recipients = [ uploader, project.coordinator_membership ].compact.uniq.reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "document_changes_requested",
        organization: project.operating_organization,
        subject: document,
        audit_event: audit_event,
        title: "Changes requested on #{project.reference_number}: #{document.title}"
      )
    end

    def document_approved(document:, audit_event:, actor:)
      project = document.project
      uploader = document.current_version&.uploaded_by_membership
      recipients = [ uploader, project.coordinator_membership ].compact.uniq.reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "document_approved",
        organization: project.operating_organization,
        subject: document,
        audit_event: audit_event,
        title: "Approved on #{project.reference_number}: #{document.title}"
      )
    end

    def document_released(document:, audit_event:, actor:)
      project = document.project
      recipients = staff_with_permissions(project.operating_organization, "projects.view_all")
                       .reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "document_released",
        organization: project.operating_organization,
        subject: document,
        audit_event: audit_event,
        title: "Shared with client on #{project.reference_number}: #{document.title}"
      )
    end

    def document_release_revoked(document:, audit_event:, actor:)
      project = document.project
      recipients = delivery_staff(project).reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "document_release_revoked",
        organization: project.operating_organization,
        subject: document,
        audit_event: audit_event,
        title: "Client access withdrawn on #{project.reference_number}: #{document.title}"
      )
    end

    def inspection_assigned(inspection:, audit_event:, actor:)
      project = inspection.project
      recipients = [ inspection.assigned_surveyor_membership ].compact.reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "inspection_assigned",
        organization: project.operating_organization,
        subject: inspection,
        audit_event: audit_event,
        title: "You were assigned inspection #{inspection.reference_number} on #{project.reference_number}"
      )
    end

    def inspection_submitted(inspection:, audit_event:, actor:)
      project = inspection.project
      recipients = review_staff(project).reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "inspection_submitted",
        organization: project.operating_organization,
        subject: inspection,
        audit_event: audit_event,
        title: "Inspection submitted on #{project.reference_number}: #{inspection.title}"
      )
    end

    def report_review_required(report:, audit_event:, actor:)
      project = report.project
      recipients = review_staff(project).reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "report_review_required",
        organization: project.operating_organization,
        subject: report,
        audit_event: audit_event,
        title: "Review required on #{project.reference_number}: #{report.title}"
      )
    end

    def report_changes_requested(report:, audit_event:, actor:)
      project = report.project
      recipients = delivery_staff(project).reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "report_changes_requested",
        organization: project.operating_organization,
        subject: report,
        audit_event: audit_event,
        title: "Changes requested on #{project.reference_number}: #{report.title}"
      )
    end

    def report_approved(report:, audit_event:, actor:)
      project = report.project
      recipients = delivery_staff(project).reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "report_approved",
        organization: project.operating_organization,
        subject: report,
        audit_event: audit_event,
        title: "Approved on #{project.reference_number}: #{report.title}"
      )
    end

    def report_released(report:, audit_event:, actor:)
      project = report.project
      recipients = delivery_staff(project).reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "report_released",
        organization: project.operating_organization,
        subject: report,
        audit_event: audit_event,
        title: "Shared with client on #{project.reference_number}: #{report.title}"
      )
    end

    def upload_requested(upload_request:, audit_event:, actor:)
      project = upload_request.project
      recipients = delivery_staff(project).reject { |m| m.id == actor.id }
      publish_subject(
        recipients,
        kind: "upload_requested",
        organization: project.operating_organization,
        subject: upload_request,
        audit_event: audit_event,
        title: "File requested on #{project.reference_number}: #{upload_request.title}"
      )
    end

    def review_staff(project)
      active_staff(project.operating_organization).select do |membership|
        Reports::Access.can_review?(membership, Report.new(project: project))
      end
    end

    def delivery_staff(project)
      active_staff(project.operating_organization).select do |membership|
        Documents::Access.staff_delivery_ops?(membership, project)
      end
    end

    def staff_with_permissions(organization, *keys)
      active_staff(organization).select do |membership|
        perms = Authorization::EffectivePermissions.new(membership)
        keys.any? { |key| perms.allowed?(key) }
      end
    end

    def publish_subject(recipients, kind:, organization:, subject:, audit_event:, title:)
      raise ArgumentError, "#{kind} is not an in-app event" unless Events.fetch(kind)[:channel] == "in_app"

      now = Time.current
      rows = recipients.uniq(&:id).filter_map do |membership|
        next unless membership.status == "active" && membership.organization_id == organization.id

        {
          organization_id: organization.id,
          recipient_membership_id: membership.id,
          audit_event_id: audit_event.id,
          kind: kind,
          subject_type: subject.class.name,
          subject_id: subject.id,
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
