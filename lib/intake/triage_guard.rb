# frozen_string_literal: true

module Intake
  # Shared checks for every staff action on an enquiry. Called inside the transaction,
  # after the enquiry row is locked.
  module TriageGuard
    STALE_MESSAGE = "Someone else updated this enquiry while you had it open. Review the latest details and try again."
    DENIED_MESSAGE = "You do not have permission to do that."

    module_function

    def authorize!(inquiry, membership, ability)
      allowed = membership&.status == "active" && membership.user&.status == "active" &&
                ServiceInquiryPolicy.new(membership, inquiry).public_send(ability)
      raise InquiryTransition::NotAuthorized, DENIED_MESSAGE unless allowed
    end

    def ensure_current!(inquiry, expected_lock_version)
      return if expected_lock_version.present? && expected_lock_version.to_s == inquiry.lock_version.to_s

      raise InquiryTransition::StaleVersion, STALE_MESSAGE
    end

    def text(value)
      value.to_s.gsub("\r\n", "\n").strip.presence
    end

    def limit!(value, maximum, label)
      return if value.nil? || value.length <= maximum

      raise InquiryTransition::InvalidTransition, "Keep the #{label} under #{maximum} characters."
    end
  end
end
