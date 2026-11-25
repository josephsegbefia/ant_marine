# frozen_string_literal: true

module Staff
  class ServiceInquiryNotesController < BaseController
    before_action :set_inquiry

    def create
      authorize @inquiry, :note?
      Intake::InquiryNotes.add!(inquiry: @inquiry, membership: Current.membership, body: params[:body])
      back notice: "Internal note added."
    end

    def correct
      authorize @inquiry, :note?
      note = @inquiry.notes.find(params[:id])
      Intake::InquiryNotes.correct!(note: note, membership: Current.membership, body: params[:body])
      back notice: "Correction added. The original note is kept in the history."
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

      def back(flash)
        redirect_to staff_service_inquiry_path(@inquiry, anchor: "enquiry-notes"), flash
      end
  end
end
