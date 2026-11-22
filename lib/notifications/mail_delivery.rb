# frozen_string_literal: true

module Notifications
  module MailDelivery
    class NotConfigured < StandardError
      def initialize
        super(
          "Production outbound email is not configured. Set SMTP_ADDRESS (and related SMTP variables) before sending mail."
        )
      end
    end

    module_function

    def configured?
      return true unless Rails.env.production?

      ENV["SMTP_ADDRESS"].present? && ActionMailer::Base.delivery_method == :smtp
    end

    def ensure_ready!
      return if configured?

      raise NotConfigured if Rails.env.production?

      true
    end

    def readiness_label
      configured? ? "ready" : "missing_smtp"
    end
  end
end
