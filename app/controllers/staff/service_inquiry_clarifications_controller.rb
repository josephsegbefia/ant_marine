# frozen_string_literal: true

module Staff
  class ServiceInquiryClarificationsController < BaseController
    before_action :set_inquiry
    before_action :set_clarification, except: :create

    def create
      authorize @inquiry, :triage?
      Intake::InquiryClarifications.prepare!(
        inquiry: @inquiry, membership: Current.membership,
        subject: params[:subject], questions: params[:questions], prepared_message: params[:prepared_message]
      )
      back notice: "Request for information prepared. Nothing has been sent — contact the client yourself, then record it here."
    end

    def record_contact
      authorize @inquiry, :triage?
      Intake::InquiryClarifications.record_contact!(clarification: @clarification, membership: Current.membership,
                                                    channel: params[:channel])
      back notice: "Contact recorded. The enquiry is now awaiting information from the client."
    end

    def record_response
      authorize @inquiry, :triage?
      Intake::InquiryClarifications.record_response!(
        clarification: @clarification, membership: Current.membership,
        response_text: params[:response_text], source: params[:source], received_on: parse_date(params[:received_on])
      )
      back notice: "Client’s answer recorded."
    end

    def withdraw
      authorize @inquiry, :triage?
      Intake::InquiryClarifications.withdraw!(clarification: @clarification, membership: Current.membership)
      back notice: "Request for information withdrawn."
    end

    rescue_from Intake::InquiryTransition::InvalidTransition do |e|
      back alert: e.message
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      back alert: e.record.errors.full_messages.to_sentence
    end

    private

      def set_inquiry
        @inquiry = policy_scope(ServiceInquiry).find(params[:service_inquiry_id])
      end

      def set_clarification
        @clarification = @inquiry.clarifications.find(params[:id])
      end

      def parse_date(value)
        Date.iso8601(value.to_s) if value.present?
      rescue Date::Error
        raise Intake::InquiryTransition::InvalidTransition, "Enter the date the answer was received."
      end

      def back(flash)
        redirect_to staff_service_inquiry_path(@inquiry, anchor: "enquiry-clarifications"), flash
      end
  end
end
