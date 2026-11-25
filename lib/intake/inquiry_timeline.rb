# frozen_string_literal: true

module Intake
  # Turns recorded audit events for an enquiry and its quotations into plain sentences.
  # Only events on the allow-list are shown; audit payloads are never displayed directly.
  class InquiryTimeline
    Entry = Struct.new(:occurred_at, :title, :detail, :actor_name, :kind, keyword_init: true)

    LOCAL_ADAPTERS = QuoteDelivery::LOCAL_ADAPTERS

    def self.entries(inquiry)
      new(inquiry).entries
    end

    def initialize(inquiry)
      @inquiry = inquiry
    end

    def entries
      events = load_events
      @memberships = Membership.includes(:user).where(id: membership_ids(events)).index_by(&:id)
      events.filter_map { |event| build(event) }
    end

    private

      def load_events
        quote_ids = @inquiry.quotes.pluck(:id)
        scope = AuditEvent.where(subject_type: "ServiceInquiry", subject_id: @inquiry.id)
        scope = scope.or(AuditEvent.where(subject_type: "Quote", subject_id: quote_ids)) if quote_ids.any?
        scope.where(organization_id: @inquiry.organization_id).order(occurred_at: :desc, id: :desc).limit(200).to_a
      end

      def membership_ids(events)
        events.flat_map do |event|
          [ event.actor_membership_id, event.metadata["previous_membership_id"], event.metadata["new_membership_id"] ]
        end.compact.uniq
      end

      def build(event)
        title, detail, kind = describe(event.event_type, event.metadata)
        return nil unless title

        Entry.new(occurred_at: event.occurred_at, title: title, detail: detail, kind: kind || "activity",
                  actor_name: event.event_type == "service_inquiry.submitted" ? nil : name_for(event.actor_membership_id))
      end

      def describe(type, data)
        enquiry_event(type, data) || clarification_event(type, data) || quotation_event(type, data)
      end

      def enquiry_event(type, data)
        case type
        when "service_inquiry.submitted" then [ "Enquiry received through the website", nil, "received" ]
        when "service_inquiry.assigned" then [ "Assigned to #{name_for(data['new_membership_id'])}", data["reason"], "assigned" ]
        when "service_inquiry.reassigned"
          [ "Responsibility moved from #{name_for(data['previous_membership_id'])} to #{name_for(data['new_membership_id'])}",
            data["reason"], "assigned" ]
        when "service_inquiry.unassigned" then [ "Returned to the unassigned list", data["reason"], "assigned" ]
        when "service_inquiry.start_review" then [ "Review started", nil, "review" ]
        when "service_inquiry.qualify" then [ "Marked ready to quote", nil, "qualified" ]
        when "service_inquiry.await_information" then [ "Waiting for information from the client", nil, "waiting" ]
        when "service_inquiry.information_received" then [ "Nothing left waiting for the client — back under review", nil, "review" ]
        when "service_inquiry.mark_outside_scope" then [ "Marked outside our service scope", data["note"], "closed" ]
        when "service_inquiry.mark_duplicate" then [ "Marked as a duplicate of #{data['duplicate_of_reference']}", data["note"], "closed" ]
        when "service_inquiry.close"
          [ "Closed — #{ServiceInquiry::CLOSE_REASONS.fetch(data['closure_reason'].to_s, 'reason recorded').downcase}", data["note"], "closed" ]
        when "service_inquiry.reopen" then [ "Reopened", data["reason"], "reopened" ]
        when "service_inquiry.note_added" then [ "Internal note added", nil, "note" ]
        when "service_inquiry.note_corrected" then [ "Internal note corrected (original kept)", nil, "note" ]
        when "service_inquiry.quotation_started" then [ "Quotation #{data['quote_reference']} started", nil, "quotation" ]
        end
      end

      def clarification_event(type, data)
        case type
        when "service_inquiry.clarification_prepared" then [ "Clarification request prepared (not sent)", nil, "clarification" ]
        when "service_inquiry.clarification_contact_recorded"
          channel = ServiceInquiryClarification::CONTACT_CHANNELS.fetch(data["contact_channel"].to_s, "another channel").downcase
          [ "Client contacted outside this system (#{channel})", nil, "clarification" ]
        when "service_inquiry.clarification_answered"
          source = ServiceInquiryClarification::RESPONSE_SOURCES.fetch(data["response_source"].to_s, "another channel").downcase
          [ "Client’s answer recorded (received by #{source})", nil, "clarification" ]
        when "service_inquiry.clarification_withdrawn" then [ "Clarification request withdrawn", nil, "clarification" ]
        end
      end

      def quotation_event(type, data)
        reference = data["reference_number"]
        version = data["version_number"] ? " version #{data['version_number']}" : ""
        case type
        when "quote.submit_for_review" then [ "Quotation #{reference} sent for internal review", nil, "quotation" ]
        when "quote.return_for_correction" then [ "Quotation #{reference} returned for correction", nil, "quotation" ]
        when "quote.approve" then [ "Quotation #{reference} approved by an independent reviewer", nil, "quotation" ]
        when "quote.withdraw" then [ "Quotation #{reference} withdrawn", nil, "quotation" ]
        when "quote.revision_created" then [ "Version #{data['version_number']} of quotation #{reference} started", nil, "quotation" ]
        when "quote.delivery_prepared" then [ "Quotation #{reference}#{version} prepared for sending — not sent", nil, "quotation" ]
        when "quote.delivery_queued" then [ "Quotation #{reference}#{version} queued for sending — not sent yet", nil, "quotation" ]
        when "quote.delivery_cancelled" then [ "Sending of quotation #{reference}#{version} cancelled — nothing was sent", nil, "quotation" ]
        when "quote.delivery_failed" then [ "Sending of quotation #{reference}#{version} failed — not sent", nil, "quotation" ]
        when "quote.delivery_outcome_unknown" then [ "Sending of quotation #{reference}#{version} has an unknown outcome", nil, "quotation" ]
        when "quote.delivery_accepted"
          if LOCAL_ADAPTERS.include?(data["delivery_adapter"].to_s)
            [ "Quotation #{reference}#{version} sent in test mode — no real email was sent", nil, "quotation" ]
          else
            [ "Quotation #{reference}#{version} accepted by the mail provider — delivery not confirmed", nil, "quotation" ]
          end
        end
      end

      def name_for(membership_id)
        membership = @memberships[membership_id.to_i]
        return "a former team member" unless membership

        membership.user.full_name.presence || membership.user.email
      end
  end
end
