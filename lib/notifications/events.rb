# frozen_string_literal: true

module Notifications
  # Delivery events that exist today. Staff enquiry notices are in-app only (StaffPublisher);
  # SMS and product reminders are later slices.
  module Events
    INVITATION_ISSUED = "invitation.issued"
    PASSWORD_RESET_REQUESTED = "password.reset_requested"

    CATALOGUE = {
      INVITATION_ISSUED => { category: "access", channel: "email" },
      PASSWORD_RESET_REQUESTED => { category: "access", channel: "email" },
      "new_enquiry" => { category: "enquiries", channel: "in_app" },
      "enquiry_assigned" => { category: "enquiries", channel: "in_app" },
      "enquiry_reassigned_away" => { category: "enquiries", channel: "in_app" },
      "clarification_answered" => { category: "enquiries", channel: "in_app" },
      "quote_accepted" => { category: "quotations", channel: "in_app" },
      "quote_declined" => { category: "quotations", channel: "in_app" },
      "quote_changes_requested" => { category: "quotations", channel: "in_app" },
      "project_created" => { category: "projects", channel: "in_app" },
      "project_assigned" => { category: "projects", channel: "in_app" },
      "project_assignment_changed" => { category: "projects", channel: "in_app" },
      "task_assigned" => { category: "projects", channel: "in_app" },
      "schedule_confirmed" => { category: "projects", channel: "in_app" },
      "schedule_cancelled" => { category: "projects", channel: "in_app" },
      "project_update" => { category: "projects", channel: "in_app" },
      "document_uploaded" => { category: "documents", channel: "in_app" },
      "document_review_required" => { category: "documents", channel: "in_app" },
      "document_changes_requested" => { category: "documents", channel: "in_app" },
      "document_approved" => { category: "documents", channel: "in_app" },
      "document_released" => { category: "documents", channel: "in_app" },
      "document_release_revoked" => { category: "documents", channel: "in_app" },
      "upload_requested" => { category: "documents", channel: "in_app" },
      "inspection_assigned" => { category: "inspections", channel: "in_app" },
      "inspection_submitted" => { category: "inspections", channel: "in_app" },
      "report_review_required" => { category: "reports", channel: "in_app" },
      "report_changes_requested" => { category: "reports", channel: "in_app" },
      "report_approved" => { category: "reports", channel: "in_app" },
      "report_released" => { category: "reports", channel: "in_app" }
    }.freeze

    def self.fetch(key)
      CATALOGUE.fetch(key) { raise KeyError, "Unknown notification event: #{key}" }
    end
  end
end
