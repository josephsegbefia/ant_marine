# frozen_string_literal: true

module Staff
  class InspectionsController < BaseController
    PER_PAGE = 25
    before_action :set_inspection, only: %i[show submit request_corrections complete]

    def index
      authorize Inspection
      scope = policy_scope(Inspection).includes(:project, :assigned_surveyor_membership)
      @pagination = Pagination.new(scope.order(updated_at: :desc, id: :desc), page: params[:page], per_page: PER_PAGE)
      @inspections = @pagination.records
    end

    def show
      authorize @inspection
      @responses = @inspection.inspection_checklist_responses.index_by(&:item_key)
      @findings = @inspection.inspection_findings.order(:id)
      @evidence_links = @inspection.inspection_evidence_links.includes(document_version: :document)
      @project_documents = Documents::Access.visible_documents_for_project(Current.membership, @inspection.project)
                                          .includes(document_versions: :storage_asset)
    end

    def new
      @project = policy_scope(Project).find(params.require(:project_id))
      authorize Inspection.new(project: @project), :create?
      @inspection = Inspection.new(project: @project)
    end

    def create
      @project = policy_scope(Project).find(params.require(:project_id))
      authorize Inspection.new(project: @project), :create?
      assignee = assignee_from_params
      result = Inspections::Create.call(
        membership: Current.membership,
        project: @project,
        title: inspection_params[:title],
        inspection_type: inspection_params[:inspection_type],
        assignee: assignee,
        vessel_name: inspection_params[:vessel_name],
        location: inspection_params[:location]
      )
      redirect_to staff_inspection_path(result.inspection), notice: "Inspection #{result.inspection.reference_number} created."
    rescue Inspections::Create::Denied, Inspections::Create::InvalidState, Inspections::Create::Error => e
      @inspection = Inspection.new(inspection_params.merge(project: @project))
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def submit
      authorize @inspection, :submit?
      Inspections::Submit.call(
        membership: Current.membership,
        inspection: @inspection,
        confirmation: params[:confirm]
      )
      redirect_to staff_inspection_path(@inspection), notice: "Inspection submitted for review."
    rescue Inspections::Submit::Denied, Inspections::Submit::InvalidState, Inspections::Submit::Error => e
      redirect_to staff_inspection_path(@inspection), alert: e.message
    end

    def request_corrections
      authorize @inspection, :request_corrections?
      Inspections::RequestCorrections.call(
        membership: Current.membership,
        inspection: @inspection,
        comments: params.require(:comments)
      )
      redirect_to staff_inspection_path(@inspection), notice: "Corrections requested."
    rescue Inspections::RequestCorrections::Denied, Inspections::RequestCorrections::InvalidState => e
      redirect_to staff_inspection_path(@inspection), alert: e.message
    end

    def complete
      authorize @inspection, :complete?
      Inspections::Complete.call(membership: Current.membership, inspection: @inspection)
      redirect_to staff_inspection_path(@inspection), notice: "Inspection marked complete."
    rescue Inspections::Complete::Denied, Inspections::Complete::InvalidState => e
      redirect_to staff_inspection_path(@inspection), alert: e.message
    end

    private

      def set_inspection
        @inspection = policy_scope(Inspection).find(params[:id])
      end

      def inspection_params
        params.fetch(:inspection, {}).permit(:title, :inspection_type, :vessel_name, :location, :assigned_surveyor_membership_id)
      end

      def assignee_from_params
        id = inspection_params[:assigned_surveyor_membership_id]
        return nil if id.blank?

        Membership.active.where(organization_id: @project.operating_organization_id).find(id)
      end
  end
end
