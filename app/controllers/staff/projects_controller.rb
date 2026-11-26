# frozen_string_literal: true

module Staff
  class ProjectsController < BaseController
    PER_PAGE = 25
    before_action :set_project, only: %i[show transition]

    def index
      authorize Project
      scope = policy_scope(Project).includes(:client_organization, :coordinator_membership, :service).recent_first
      apply_view_filter!(scope)
      scope = apply_search(scope)
      @summary = summary_counts
      @pagination = Pagination.new(@filtered_scope, page: params[:page], per_page: PER_PAGE)
      @projects = @pagination.records
      assign_staff_breadcrumb(crumbs: [], current: "Projects")
    end

    def show
      authorize @project
      @tab = params[:tab].presence_in(%w[overview team milestones tasks schedule activity]) || "overview"
      @actions = Delivery::Transition.available_actions(@project)
      @assignments = @project.assignments.includes(:user, :membership).order(active: :desc, created_at: :desc)
      @milestones = @project.project_milestones
      @tasks = @project.tasks.includes(:assignee_membership).order(Arel.sql("CASE status WHEN 'todo' THEN 0 WHEN 'in_progress' THEN 1 WHEN 'blocked' THEN 2 ELSE 3 END"), :due_on, :id)
      @events = @project.schedule_events.includes(:responsible_membership).order(:starts_at)
      @updates = @project.project_updates.recent_first.limit(20)
      @status_events = @project.project_status_events.includes(:actor_membership).order(occurred_at: :desc).limit(40)
      @staff_options = Membership.active.where(organization: @project.operating_organization).joins(:user).where(users: { status: "active" }).includes(:user).select(&:staff_domain?)
      assign_staff_breadcrumb(
        crumbs: [ { label: "Projects", path: staff_projects_path } ],
        current: @project.reference_number
      )
    end

    def new
      authorize Project
      @step = (params[:step].presence || "1").to_i.clamp(1, 4)
      @response = find_acceptance!(params[:quote_response_id])
      existing = Project.find_by(quote_response_id: @response.id)
      return redirect_to staff_project_path(existing), notice: "A project already exists for this acceptance." if existing

      @project = Project.new(
        title: @response.quote_revision.title,
        operational_description: @response.quote_revision.scope_description,
        service_id: @response.quote.service_id
      )
      @staff_options = Membership.active.where(organization: Organization.ant_marine!).joins(:user).where(users: { status: "active" }).includes(:user).select(&:staff_domain?)
      assign_staff_breadcrumb(crumbs: [ { label: "Projects", path: staff_projects_path } ], current: "Create project")
    end

    def create
      authorize Project
      @response = find_acceptance!(params.require(:quote_response_id))
      @step = (params[:step].presence || "4").to_i
      result = Delivery::CreateFromAcceptance.call(
        membership: Current.membership,
        quote_response: @response,
        attributes: project_params,
        confirmation: params.dig(:project, :confirm)
      )
      notice = result.created ? "Project #{result.project.reference_number} created." : "Opened the existing project for this acceptance."
      redirect_to staff_project_path(result.project), notice: notice
    rescue Delivery::CreateFromAcceptance::Denied => e
      redirect_to staff_projects_path, alert: e.message
    rescue Delivery::CreateFromAcceptance::InvalidState, Delivery::CreateFromAcceptance::Error, Delivery::CreateFromAcceptance::Conflict => e
      @project = Project.new(project_params)
      @staff_options = Membership.active.where(organization: Organization.ant_marine!).joins(:user).where(users: { status: "active" }).includes(:user).select(&:staff_domain?)
      flash.now[:alert] = e.message
      assign_staff_breadcrumb(crumbs: [ { label: "Projects", path: staff_projects_path } ], current: "Create project")
      render :new, status: :unprocessable_entity
    end

    def transition
      authorize @project, :transition?
      Delivery::Transition.apply!(
        project: @project,
        action: params.require(:project_action),
        membership: Current.membership,
        reason: params[:reason]
      )
      redirect_to staff_project_path(@project), notice: "Project status updated."
    rescue Delivery::Transition::Denied, Delivery::Transition::InvalidState, Delivery::Transition::Error => e
      redirect_to staff_project_path(@project), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).includes(
          :client_organization, :service, :quote, :quote_revision,
          coordinator_membership: :user
        ).find(params[:id])
      end

      def find_acceptance!(id)
        response = QuoteResponse.find(id)
        raise ActiveRecord::RecordNotFound unless response.accepted?

        response
      end

      def project_params
        params.fetch(:project, {}).permit(
          :title, :location, :vessel_name, :vessel_identifier, :operational_description,
          :internal_notes, :proposed_start_on, :target_completion_on, :coordinator_membership_id, :service_id
        )
      end

      def apply_view_filter!(scope)
        @view = params[:view].presence_in(%w[all mine planning active on_hold completed]) || "all"
        @filtered_scope = case @view
        when "mine"
          scope.where(id: Assignment.active.where(user_id: Current.user.id).select(:project_id))
               .or(scope.where(coordinator_membership_id: Current.membership.id))
        when "planning" then scope.where(internal_status: %w[planning scheduled])
        when "active" then scope.where(internal_status: %w[in_progress technical_review report_ready])
        when "on_hold" then scope.where(internal_status: "on_hold")
        when "completed" then scope.where(internal_status: %w[completed closed])
        else scope
        end
      end

      def apply_search(scope)
        return @filtered_scope if params[:q].blank?

        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
        @filtered_scope = @filtered_scope.left_joins(:client_organization).where(
          "projects.reference_number ILIKE :t OR projects.title ILIKE :t OR organizations.name ILIKE :t",
          t: term
        )
      end

      def summary_counts
        base = policy_scope(Project)
        {
          all: base.count,
          mine: base.where(id: Assignment.active.where(user_id: Current.user.id).select(:project_id))
                    .or(base.where(coordinator_membership_id: Current.membership.id)).count,
          planning: base.where(internal_status: %w[planning scheduled]).count,
          active: base.where(internal_status: %w[in_progress technical_review report_ready]).count,
          on_hold: base.where(internal_status: "on_hold").count,
          completed: base.where(internal_status: %w[completed closed]).count
        }
      end
  end
end
