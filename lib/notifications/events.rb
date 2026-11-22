# frozen_string_literal: true

module Notifications
  # Delivery events that exist today. Inbox rows, SMS, and product reminders are later slices.
  module Events
    INVITATION_ISSUED = "invitation.issued"
    PASSWORD_RESET_REQUESTED = "password.reset_requested"

    CATALOGUE = {
      INVITATION_ISSUED => { category: "access", channel: "email" },
      PASSWORD_RESET_REQUESTED => { category: "access", channel: "email" }
    }.freeze

    def self.fetch(key)
      CATALOGUE.fetch(key) { raise KeyError, "Unknown notification event: #{key}" }
    end
  end
end
