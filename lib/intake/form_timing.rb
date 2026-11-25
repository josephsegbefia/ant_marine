# frozen_string_literal: true

module Intake
  # Signed "form opened at" stamp. Real visitors take a few seconds to complete the
  # form; scripted submissions usually post immediately or without a stamp at all.
  module FormTiming
    PURPOSE = :public_enquiry_form
    MINIMUM_SECONDS = 3
    MAXIMUM_AGE = 12.hours

    module_function

    def issue(now = Time.current)
      verifier.generate(now.to_i, expires_in: MAXIMUM_AGE)
    end

    def elapsed_seconds(stamp, now = Time.current)
      opened_at = verifier.verified(stamp.to_s)
      return nil unless opened_at.is_a?(Integer)

      now.to_i - opened_at
    end

    def human_pace?(stamp, now = Time.current)
      elapsed = elapsed_seconds(stamp, now)
      elapsed.present? && elapsed >= MINIMUM_SECONDS
    end

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
