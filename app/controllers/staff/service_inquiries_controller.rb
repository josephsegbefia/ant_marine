# frozen_string_literal: true

module Staff
  class ServiceInquiriesController < BaseController
    before_action :set_inquiry, only: %i[show prepare_quotation]

    def index
      authorize ServiceInquiry
      assign_staff_breadcrumb(crumbs: [], current: "Enquiries")
      @inquiries = policy_scope(ServiceInquiry).includes(:quotes).recent_first
      apply_filters!
    end

    def show
      authorize @inquiry
      assign_staff_breadcrumb(crumbs: [ { label: "Enquiries", path: staff_service_inquiries_path } ],
                              current: @inquiry.reference_number)
      @open_quote = @inquiry.open_quote
      @history = AuditEvent.where(subject_type: "ServiceInquiry", subject_id: @inquiry.id)
                           .includes(actor_membership: :user).order(occurred_at: :desc).limit(10)
    end

    def prepare_quotation
      authorize @inquiry
      result = Commercial::QuoteFromInquiry.call(inquiry: @inquiry, membership: Current.membership)
      notice = if result.created
                 "Draft quotation started from #{@inquiry.reference_number}. Add the scope, pricing and terms."
      else
                 "This enquiry already has a quotation in progress. Opened the existing quotation."
      end
      redirect_to edit_staff_quotation_path(result.quote, editor_step: 1), notice: notice
    rescue Commercial::QuoteFromInquiry::NotEligible, Commercial::QuoteFromInquiry::NotAuthorized => e
      redirect_to staff_service_inquiry_path(@inquiry), alert: e.message
    end

    private

      def set_inquiry
        @inquiry = policy_scope(ServiceInquiry).find(params[:id])
      end

      def apply_filters!
        if params[:q].present?
          term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
          @inquiries = @inquiries.where(
            "service_inquiries.reference_number ILIKE :term OR service_inquiries.company_name ILIKE :term OR " \
            "service_inquiries.contact_name ILIKE :term",
            term: term
          )
        end
        return if params[:status].blank? || params[:status] == "all"

        @inquiries = @inquiries.where(current_status: params[:status]) if ServiceInquiry::STATUSES.include?(params[:status])
      end
  end
end
