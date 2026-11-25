# frozen_string_literal: true

module Intake
  # Saves a public enquiry exactly once per submission token. A repeated POST with the
  # same token (refresh, back button, double click) returns the enquiry already saved.
  class InquirySubmission
    FIELDS = %i[company_name contact_name contact_email contact_phone project_name vessel_name
                location description preferred_date].freeze
    ATTEMPTS = 3

    Result = Struct.new(:inquiry, :created, keyword_init: true) do
      def saved? = inquiry.persisted?
      def duplicate? = saved? && !created
    end

    def self.submit!(attributes:, service_choice:, submission_token:, request_meta: {})
      new(attributes:, service_choice:, submission_token:, request_meta:).submit!
    end

    def initialize(attributes:, service_choice:, submission_token:, request_meta: {})
      @attributes = attributes.to_h.symbolize_keys.slice(*FIELDS)
      @service_choice = service_choice.to_s.strip
      @token = submission_token.to_s
      @request_meta = request_meta
    end

    def submit!
      existing = existing_inquiry
      return Result.new(inquiry: existing, created: false) if existing

      inquiry = build_inquiry
      attempts = 0
      begin
        attempts += 1
        saved = false
        ServiceInquiry.transaction(requires_new: true) do
          inquiry.reference_number = InquiryReference.generate!
          inquiry.submitted_at = Time.current
          raise ActiveRecord::Rollback unless inquiry.save

          saved = true
          event = AuditEvent.record!(
            event_type: "service_inquiry.submitted",
            organization: inquiry.organization,
            subject: inquiry,
            metadata: {
              reference_number: inquiry.reference_number,
              channel: inquiry.channel,
              service_id: inquiry.service_id
            }.compact
          )
          Notifications::StaffPublisher.new_enquiry(inquiry: inquiry, audit_event: event)
        end
        unless saved
          existing = existing_inquiry
          return Result.new(inquiry: existing, created: false) if existing

          inquiry.reference_number = nil
          inquiry.submitted_at = nil
        end
        Result.new(inquiry: inquiry, created: saved)
      rescue ActiveRecord::RecordNotUnique
        existing = existing_inquiry
        return Result.new(inquiry: existing, created: false) if existing

        inquiry.reference_number = nil
        retry if attempts < ATTEMPTS
        raise
      end
    end

    private

      def existing_inquiry
        return nil if @token.blank?

        ServiceInquiry.find_by(submission_token: @token)
      end

      def build_inquiry
        organization = Organization.ant_marine!
        service = resolve_service(organization)
        ServiceInquiry.new(
          @attributes.merge(
            organization: organization,
            channel: "public_form",
            current_status: "submitted",
            service: service,
            service_title_snapshot: service&.public_title,
            service_choice: @service_choice,
            submission_token: @token.presence || SecureRandom.urlsafe_base64(24),
            submission_metadata: @request_meta.compact
          )
        )
      end

      def resolve_service(organization)
        return nil if @service_choice.blank? || @service_choice == ServiceInquiry::NOT_SURE

        Service.published_catalogue.find_by(organization: organization, slug: @service_choice)
      end
  end
end
