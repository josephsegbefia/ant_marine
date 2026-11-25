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
      "quote_changes_requested" => { category: "quotations", channel: "in_app" }
    }.freeze

    def self.fetch(key)
      CATALOGUE.fetch(key) { raise KeyError, "Unknown notification event: #{key}" }
    end
  end
end
