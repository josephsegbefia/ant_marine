# frozen_string_literal: true

module Staff
  class InspectionFindingsController < BaseController
    before_action :set_inspection

    def create
      authorize @inspection, :update?
      payload = params.require(:finding)
      Inspections::RecordFinding.call(
        membership: Current.membership,
        inspection: @inspection,
        title: payload.require(:title),
        observation: payload.require(:observation),
        classification: payload[:classification],
        recommendation: payload[:recommendation],
        location_or_equipment: payload[:location_or_equipment],
        checklist_item_key: payload[:checklist_item_key]
      )
      redirect_to staff_inspection_path(@inspection), notice: "Finding recorded."
    rescue Inspections::RecordFinding::Denied, Inspections::RecordFinding::InvalidState => e
      redirect_to staff_inspection_path(@inspection), alert: e.message
    end

    private

      def set_inspection
        @inspection = policy_scope(Inspection).find(params[:inspection_id])
      end
  end
end
