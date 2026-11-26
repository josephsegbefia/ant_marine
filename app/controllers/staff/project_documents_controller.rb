# frozen_string_literal: true

module Staff
  class ProjectDocumentsController < BaseController
    PER_PAGE = 25
    before_action :set_project
    before_action :set_document, only: %i[show submit_for_review]

    def index
      authorize Document
      raise ActiveRecord::RecordNotFound unless Documents::Access.can_list_project_documents?(Current.membership, @project)

      scope = Documents::Access.visible_documents_for_project(Current.membership, @project)
                               .includes(:current_version)
      apply_filters!(scope)
      @summary = summary_counts(scope)
      @pagination = Pagination.new(@filtered_scope.order(updated_at: :desc, id: :desc),
                                   page: params[:page], per_page: PER_PAGE)
      @documents = @pagination.records
      assign_staff_breadcrumb(
        crumbs: [
          { label: "Projects", path: staff_projects_path },
          { label: @project.reference_number, path: staff_project_path(@project) }
        ],
        current: "Documents"
      )
    end

    def show
      authorize @document
      @versions = @document.document_versions.includes(:storage_asset, :uploaded_by_membership, :document_reviews).order(version_number: :desc)
      @releases = @document.document_releases.includes(:document_version, :released_by_membership).order(released_at: :desc)
      @upload_requests = UploadRequest.where(project_id: @project.id).order(created_at: :desc).limit(20)
      assign_staff_breadcrumb(
        crumbs: [
          { label: "Projects", path: staff_projects_path },
          { label: @project.reference_number, path: staff_project_path(@project) },
          { label: "Documents", path: staff_project_documents_path(@project) }
        ],
        current: @document.title
      )
    end

    def new
      authorize Document.new(project: @project), :create?
      @document = Document.new(project: @project, classification: "standard", visibility_intent: "internal")
      assign_staff_breadcrumb(
        crumbs: [
          { label: "Projects", path: staff_projects_path },
          { label: @project.reference_number, path: staff_project_path(@project) },
          { label: "Documents", path: staff_project_documents_path(@project) }
        ],
        current: "Upload file"
      )
    end

    def create
      authorize Document.new(project: @project), :create?
      file = params.require(:document).require(:file)
      result = Documents::Upload.call(
        membership: Current.membership,
        project: @project,
        filename: file.original_filename,
        io: file.tempfile,
        title: document_params[:title],
        category: document_params[:category],
        classification: document_params[:classification],
        visibility_intent: document_params[:visibility_intent],
        description: document_params[:description]
      )
      redirect_to staff_project_document_path(@project, result.document),
                  notice: "File uploaded. Security checks will run before download is allowed."
    rescue Documents::Upload::Denied, Documents::Upload::InvalidState, Documents::Upload::Error => e
      @document = Document.new(document_params.merge(project: @project))
      flash.now[:alert] = e.message
      assign_staff_breadcrumb(
        crumbs: [
          { label: "Projects", path: staff_projects_path },
          { label: @project.reference_number, path: staff_project_path(@project) },
          { label: "Documents", path: staff_project_documents_path(@project) }
        ],
        current: "Upload file"
      )
      render :new, status: :unprocessable_entity
    end

    def submit_for_review
      authorize @document, :submit_for_review?
      version = @document.current_version
      Documents::SubmitForReview.call(membership: Current.membership, document: @document, version: version)
      redirect_to staff_project_document_path(@project, @document), notice: "Submitted for review."
    rescue Documents::SubmitForReview::Denied, Documents::SubmitForReview::InvalidState, Documents::SubmitForReview::Error => e
      redirect_to staff_project_document_path(@project, @document), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end

      def set_document
        @document = policy_scope(Document).where(project_id: @project.id).find(params[:id])
      end

      def document_params
        params.fetch(:document, {}).permit(:title, :category, :classification, :visibility_intent, :description)
      end

      def apply_filters!(scope)
        @category = params[:category].presence
        @workflow = params[:workflow].presence_in(Document::WORKFLOW_STATUSES)
        @visibility = params[:visibility].presence_in(Document::VISIBILITY_INTENTS)
        @security = params[:security].presence_in(%w[pending available rejected])

        @filtered_scope = scope
        @filtered_scope = @filtered_scope.where(category: @category) if @category
        @filtered_scope = @filtered_scope.where(workflow_status: @workflow) if @workflow
        @filtered_scope = @filtered_scope.where(visibility_intent: @visibility) if @visibility
        if @security == "pending"
          @filtered_scope = @filtered_scope.joins(current_version: :storage_asset)
                                           .where(storage_assets: { scan_status: %w[pending_upload scanning] })
        elsif @security == "available"
          @filtered_scope = @filtered_scope.joins(current_version: :storage_asset)
                                           .where(storage_assets: { scan_status: "available" })
        elsif @security == "rejected"
          @filtered_scope = @filtered_scope.joins(current_version: :storage_asset)
                                           .where(storage_assets: { scan_status: "rejected" })
        end
      end

      def summary_counts(scope)
        base = scope.not_archived
        {
          all: base.count,
          working_draft: base.where(workflow_status: "working_draft").count,
          submitted: base.where(workflow_status: "submitted").count,
          released: base.where(workflow_status: "released").count
        }
      end
  end
end
