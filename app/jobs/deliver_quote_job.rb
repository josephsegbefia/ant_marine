# frozen_string_literal: true

require "net/smtp"

# Sends one queued quotation delivery at most once. The record is moved to "sending"
# and committed before the mail system is contacted, so a crash or timeout leaves a
# visible "outcome unknown" instead of a silent second send. Nothing is retried
# automatically; a person decides what to do next.
class DeliverQuoteJob < ApplicationJob
  queue_as :mail

  self.log_arguments = false

  REFUSED_ERRORS = [ Net::SMTPFatalError, Net::SMTPSyntaxError, Net::SMTPServerBusy, Net::SMTPAuthenticationError ].freeze

  def perform(delivery_id)
    delivery = claim(delivery_id)
    return unless delivery

    message = QuotesMailer.quotation(delivery).deliver_now
    record_accepted(delivery, message)
  rescue *REFUSED_ERRORS => e
    record_outcome(delivery, "failed", "The mail server refused the message (#{e.class.name.demodulize}).") if delivery
  rescue Notifications::MailDelivery::NotConfigured
    record_outcome(delivery, "failed", "Outbound email is not configured.") if delivery
  rescue StandardError => e
    raise unless delivery

    record_outcome(delivery, "outcome_unknown", "No clear answer from the mail system (#{e.class.name.demodulize}).")
  end

  private

    def claim(delivery_id)
      QuoteDelivery.transaction do
        delivery = QuoteDelivery.lock.find_by(id: delivery_id)
        next nil unless delivery&.status == "queued"

        quote = delivery.quote
        unless sendable?(delivery, quote)
          finish(delivery, "cancelled", cancelled_at: Time.current,
                                        failure_reason: "The quotation changed before it was sent, so nothing was sent.")
          next nil
        end

        delivery.update!(status: "sending", attempted_at: Time.current, attempt_count: delivery.attempt_count + 1)
        sync(delivery)
        delivery
      end
    end

    def sendable?(delivery, quote)
      Commercial::QuoteIssuance.dispatch_available? &&
        quote.status == "approved_for_issuance" &&
        quote.current_revision_id == delivery.quote_revision_id &&
        delivery.quote_revision.revision_status == "approved"
    end

    def record_accepted(delivery, message)
      Quote.transaction do
        quote = Quote.lock.find(delivery.quote_id)
        delivery.lock!
        now = Time.current
        delivery.update!(status: "accepted_by_provider", accepted_at: now,
                         provider_message_id: message&.message_id.to_s.first(255).presence,
                         provider_response: "accepted by #{delivery.delivery_adapter} adapter")
        revision = delivery.quote_revision
        revision.update!(revision_status: "issued", issued_at: now, issued_by_membership_id: delivery.dispatched_by_membership_id)
        quote.update!(status: "issued", updated_by_membership_id: delivery.dispatched_by_membership_id)
        superseded = Commercial::QuoteSupersession.after_issue!(quote: quote, revision: revision)
        sync(delivery)
        audit(delivery, "quote.delivery_accepted", superseded_version_numbers: superseded.map(&:version_number).presence)
      end
    end

    def record_outcome(delivery, status, reason)
      QuoteDelivery.transaction do
        delivery.lock!
        attrs = { failure_reason: reason }
        attrs[:failed_at] = Time.current if status == "failed"
        finish(delivery, status, **attrs)
        audit(delivery, status == "failed" ? "quote.delivery_failed" : "quote.delivery_outcome_unknown")
      end
    end

    def finish(delivery, status, **attrs)
      delivery.update!(attrs.merge(status: status))
      sync(delivery)
    end

    def sync(delivery)
      delivery.quote.update_columns(delivery_state: delivery.quote_delivery_state, updated_at: Time.current)
    end

    def audit(delivery, event_type, extra = {})
      AuditEvent.record!(
        event_type: event_type,
        organization: delivery.organization,
        actor_membership: delivery.dispatched_by_membership,
        subject: delivery.quote,
        metadata: {
          reference_number: delivery.quote.reference_number,
          delivery_id: delivery.id,
          version_number: delivery.quote_revision.version_number,
          delivery_status: delivery.status,
          delivery_adapter: delivery.delivery_adapter,
          failure_reason: delivery.failure_reason
        }.merge(extra).compact
      )
    end
end
