# frozen_string_literal: true

module Intake
  # Clarification requests. Nothing is sent by the system: preparing a request is internal,
  # "contact recorded" means a staff member contacted the client through their own channel,
  # and an answer is recorded with its source and the person who recorded it.
  # The enquiry moves to "Awaiting information" only once the client has actually been asked,
  # and back to "Under review" when nothing is left waiting for the client.
  class InquiryClarifications
    def self.prepare!(inquiry:, membership:, subject:, questions:, prepared_message: nil)
      new(inquiry:, membership:).prepare!(subject:, questions:, prepared_message:)
    end

    def self.record_contact!(clarification:, membership:, channel:)
      new(inquiry: clarification.service_inquiry, membership:).record_contact!(clarification, channel)
    end

    def self.record_response!(clarification:, membership:, response_text:, source:, received_on: nil)
      new(inquiry: clarification.service_inquiry, membership:).record_response!(clarification, response_text, source, received_on)
    end

    def self.withdraw!(clarification:, membership:)
      new(inquiry: clarification.service_inquiry, membership:).withdraw!(clarification)
    end

    def initialize(inquiry:, membership:)
      @inquiry = inquiry
      @membership = membership
    end

    def prepare!(subject:, questions:, prepared_message:)
      within_lock do
        raise InquiryTransition::InvalidTransition, "Reopen this enquiry before asking the client for more information." unless @inquiry.open?

        clarification = @inquiry.clarifications.create!(
          created_by_membership: @membership, subject: subject, questions: questions, prepared_message: prepared_message
        )
        audit!("service_inquiry.clarification_prepared", clarification)
        clarification
      end
    end

    def record_contact!(clarification, channel)
      within_lock do
        clarification.lock!
        unless clarification.status == "prepared"
          raise InquiryTransition::InvalidTransition, "Contact has already been recorded for this request, or it is closed."
        end
        unless ServiceInquiryClarification::CONTACT_CHANNELS.key?(channel.to_s)
          raise InquiryTransition::InvalidTransition, "Choose how you contacted the client."
        end
        raise InquiryTransition::InvalidTransition, "Reopen this enquiry before recording contact." unless @inquiry.open?

        clarification.update!(status: "contacted_outside_system", contact_channel: channel.to_s,
                              contacted_at: Time.current, contacted_by_membership: @membership)
        audit!("service_inquiry.clarification_contact_recorded", clarification, contact_channel: channel.to_s)
        transition!("await_information") unless @inquiry.current_status == "needs_clarification"
        clarification
      end
    end

    def record_response!(clarification, response_text, source, received_on)
      within_lock do
        clarification.lock!
        unless clarification.awaiting_answer?
          raise InquiryTransition::InvalidTransition, "An answer has already been recorded, or this request was withdrawn."
        end
        unless ServiceInquiryClarification::RESPONSE_SOURCES.key?(source.to_s)
          raise InquiryTransition::InvalidTransition, "Choose how the answer was received."
        end

        clarification.update!(status: "answered", response_text: response_text, response_source: source.to_s,
                              response_received_at: received_at(received_on),
                              response_recorded_by_membership: @membership)
        event = audit!("service_inquiry.clarification_answered", clarification, response_source: source.to_s)
        return_to_review_if_nothing_waiting!
        Notifications::StaffPublisher.clarification_answered(inquiry: @inquiry, actor: @membership, audit_event: event)
        clarification
      end
    end

    def withdraw!(clarification)
      within_lock do
        clarification.lock!
        raise InquiryTransition::InvalidTransition, "Only an open request can be withdrawn." unless clarification.awaiting_answer?

        clarification.update!(status: "withdrawn", withdrawn_at: Time.current, withdrawn_by_membership: @membership)
        audit!("service_inquiry.clarification_withdrawn", clarification)
        return_to_review_if_nothing_waiting!
        clarification
      end
    end

    private

      def within_lock(&)
        ServiceInquiry.transaction do
          @inquiry.lock!
          TriageGuard.authorize!(@inquiry, @membership, :triage?)
          yield
        end
      end

      def received_at(received_on)
        return Time.current if received_on.blank?

        date = Date.iso8601(received_on.to_s)
        raise InquiryTransition::InvalidTransition, "The date the answer was received cannot be in the future." if date > Date.current

        date == Date.current ? Time.current : date.in_time_zone.change(hour: 12)
      rescue Date::Error
        raise InquiryTransition::InvalidTransition, "Enter the date the answer was received."
      end

      def return_to_review_if_nothing_waiting!
        return unless @inquiry.current_status == "needs_clarification"
        return if @inquiry.clarifications.awaiting_client.exists?

        transition!("information_received")
      end

      def transition!(action)
        InquiryTransition.apply!(inquiry: @inquiry, action: action, membership: @membership,
                                 expected_lock_version: @inquiry.lock_version)
      end

      def audit!(event_type, clarification, extra = {})
        AuditEvent.record!(
          event_type: event_type,
          organization: @inquiry.organization,
          actor_membership: @membership,
          subject: @inquiry,
          metadata: { reference_number: @inquiry.reference_number, clarification_id: clarification.id }.merge(extra)
        )
      end
  end
end
