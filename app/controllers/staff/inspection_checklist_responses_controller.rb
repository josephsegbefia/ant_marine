# frozen_string_literal: true

module Staff
  class InspectionChecklistResponsesController < BaseController
    before_action :set_inspection

    def create
      authorize @inspection, :update?
      persist_response
    end

    def update
      authorize @inspection, :update?
      persist_response
    end

    private

      def persist_response
        payload = params.require(:checklist_response)
        Inspections::SaveChecklistResponse.call(
          membership: Current.membership,
          inspection: @inspection,
          item_key: payload.require(:item_key),
          response_type: payload.require(:response_type),
          value_json: value_json_from(payload),
          not_applicable_reason: payload[:not_applicable_reason],
          lock_version: payload[:lock_version]
        )
        redirect_to staff_inspection_path(@inspection), notice: "Checklist updated."
      rescue Inspections::SaveChecklistResponse::Denied, Inspections::SaveChecklistResponse::InvalidState,
             Inspections::SaveChecklistResponse::StaleState => e
        redirect_to staff_inspection_path(@inspection), alert: e.message
      end

      def set_inspection
        @inspection = policy_scope(Inspection).find(params[:inspection_id])
      end

      def value_json_from(payload)
        case payload[:response_type]
        when "yes_no_na", "satisfactory_unsatisfactory"
          { "answer" => payload[:answer] }
        when "short_text", "long_text"
          { "text" => payload[:text] }
        when "numeric"
          { "number" => payload[:number] }
        when "date"
          { "date" => payload[:date] }
        when "single_select"
          { "selected" => payload[:selected] }
        when "multi_select"
          { "selected" => Array(payload[:selected]).reject(&:blank?) }
        else
          {}
        end
      end
  end
end
