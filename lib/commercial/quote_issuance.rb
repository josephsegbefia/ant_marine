# frozen_string_literal: true

module Commercial
  # Two separate gates:
  # - available?: the old one-click "mark as issued" without any delivery record. It stays
  #   off; a quotation only becomes issued when a recorded delivery is accepted.
  # - dispatch_available?: sending through QuoteDispatcher. Allowed only outside production
  #   and only with a local mail adapter (:test captures in memory, :file writes to
  #   tmp/mails), so no message can reach a real inbox. Production stays off until the
  #   product owner approves live delivery, wording and attachment handling.
  module QuoteIssuance
    UNAVAILABLE_MESSAGE = "Sending quotations to clients is not available yet. " \
                          "The approved PDF can be downloaded for internal use."
    DISPATCH_DISABLED_MESSAGE = "Sending quotations is switched off in this environment. " \
                                "Live email delivery has not been approved yet."
    LOCAL_ADAPTERS = %i[test file].freeze

    module_function

    def available?
      false
    end

    def dispatch_available?
      return false if Rails.env.production?
      return false if ENV["QUOTE_DISPATCH_DISABLED"].present?

      LOCAL_ADAPTERS.include?(ActionMailer::Base.delivery_method)
    end

    def adapter_name
      ActionMailer::Base.delivery_method.to_s
    end

    def mode_description
      return DISPATCH_DISABLED_MESSAGE unless dispatch_available?

      case ActionMailer::Base.delivery_method
      when :file then "Test delivery only — the email is saved to a local folder on this computer and never reaches a real inbox."
      else "Test delivery only — the email is captured by the test mail system and never reaches a real inbox."
      end
    end
  end
end
