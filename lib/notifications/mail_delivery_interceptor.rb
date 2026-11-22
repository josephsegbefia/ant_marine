# frozen_string_literal: true

module Notifications
  class MailDeliveryInterceptor
    def self.delivering_email(_message)
      MailDelivery.ensure_ready!
    end
  end
end
