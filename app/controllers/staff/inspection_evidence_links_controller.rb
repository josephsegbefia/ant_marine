# frozen_string_literal: true

module Staff
  class InspectionEvidenceLinksController < BaseController
    before_action :set_inspection

    def create
      authorize @inspection, :update?
      version = DocumentVersion.joins(:document).where(documents: { project_id: @inspection.project_id }).find(params.require(:document_version_id))
      finding = params[:finding_id].present? ? @inspection.inspection_findings.find(params[:finding_id]) : nil
      Inspections::AttachEvidence.call(
        membership: Current.membership,
        inspection: @inspection,
        document_version: version,
        finding: finding,
        checklist_item_key: params[:checklist_item_key]
      )
      redirect_to staff_inspection_path(@inspection), notice: "Evidence linked."
    rescue Inspections::AttachEvidence::Denied, Inspections::AttachEvidence::InvalidState => e
      redirect_to staff_inspection_path(@inspection), alert: e.message
    end

    def destroy
      authorize @inspection, :update?
      link = @inspection.inspection_evidence_links.find(params[:id])
      link.destroy!
      redirect_to staff_inspection_path(@inspection), notice: "Evidence link removed."
    rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::StatementInvalid => e
      redirect_to staff_inspection_path(@inspection), alert: e.message
    end

    private

      def set_inspection
        @inspection = policy_scope(Inspection).find(params[:inspection_id])
      end
  end
end
