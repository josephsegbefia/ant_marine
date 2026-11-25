# frozen_string_literal: true

module Commercial
  # Starts a draft quotation from an enquiry. Only facts the client supplied are carried
  # forward; prices, scope, deliverables, terms and validity are left for staff to write.
  # One open quotation per enquiry: repeated requests return the existing draft.
  class QuoteFromInquiry
    class NotAuthorized < StandardError; end

    class NotEligible < StandardError; end

    CLOSED_STATUSES = %w[unqualified merged closed].freeze
    Result = Struct.new(:quote, :created, keyword_init: true)

    def self.call(inquiry:, membership:)
      new(inquiry:, membership:).call
    end

    def initialize(inquiry:, membership:)
      @inquiry = inquiry
      @membership = membership
    end

    def call
      authorize!
      ServiceInquiry.transaction do
        @inquiry.lock!
        existing = @inquiry.open_quote
        next Result.new(quote: existing, created: false) if existing
        raise NotEligible, "This enquiry is closed, so a quotation cannot be prepared from it." if @inquiry.current_status.in?(CLOSED_STATUSES)

        Result.new(quote: build_quote, created: true)
      end
    rescue ActiveRecord::RecordNotUnique
      existing = @inquiry.reload.open_quote
      raise unless existing

      Result.new(quote: existing, created: false)
    end

    private

      def authorize!
        permissions = Authorization::EffectivePermissions.new(@membership)
        allowed = @membership&.status == "active" && @membership.staff_domain? &&
                  @membership.organization_id == @inquiry.organization_id &&
                  permissions.allowed?("inquiries.view_all") && permissions.allowed?("quotes.create")
        raise NotAuthorized, "You do not have permission to prepare quotations from enquiries." unless allowed
      end

      def build_quote
        quote = QuoteBuilder.create!(organization: @inquiry.organization, membership: @membership)
        quote.update!(
          service_inquiry: @inquiry,
          client_organization: @inquiry.client_organization,
          service: still_published_service,
          prospective_client: {
            "company_name" => @inquiry.company_name,
            "contact_name" => @inquiry.contact_name,
            "email" => @inquiry.contact_email,
            "phone" => @inquiry.contact_phone.to_s
          }
        )
        quote.current_revision.update!(title: suggested_title, internal_notes: enquiry_notes)

        AuditEvent.record!(
          event_type: "quote.created_from_inquiry",
          organization: @inquiry.organization,
          actor_membership: @membership,
          subject: quote,
          metadata: { reference_number: quote.reference_number, inquiry_reference: @inquiry.reference_number }
        )
        AuditEvent.record!(
          event_type: "service_inquiry.quotation_started",
          organization: @inquiry.organization,
          actor_membership: @membership,
          subject: @inquiry,
          metadata: { reference_number: @inquiry.reference_number, quote_reference: quote.reference_number }
        )
        quote
      end

      def still_published_service
        service = @inquiry.service
        service if service && Quote.assignable_services(@inquiry.organization).exists?(id: service.id)
      end

      def suggested_title
        subject = [ @inquiry.vessel_name, @inquiry.project_name ].compact_blank.first
        [ @inquiry.service_title_snapshot.presence || "Service enquiry", subject ].compact_blank.join(" — ").first(200)
      end

      def enquiry_notes
        lines = [ "From enquiry #{@inquiry.reference_number} (received #{I18n.l(@inquiry.submitted_at.to_date, format: :long)})." ]
        lines << "Location: #{@inquiry.location}" if @inquiry.location.present?
        lines << "Preferred date (requested, not confirmed): #{I18n.l(@inquiry.preferred_date, format: :long)}" if @inquiry.preferred_date
        lines << "Project: #{@inquiry.project_name}" if @inquiry.project_name.present?
        lines << "Vessel or facility: #{@inquiry.vessel_name}" if @inquiry.vessel_name.present?
        lines << "" << "What the client asked for:" << @inquiry.description.to_s
        lines.join("\n")
      end
  end
end
