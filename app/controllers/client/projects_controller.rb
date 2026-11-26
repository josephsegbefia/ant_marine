# frozen_string_literal: true

module Client
  class ProjectsController < BaseController
    def index
      authorize Project
      scope = policy_scope(Project).includes(:service).recent_first
      @pagination = Pagination.new(scope, page: params[:page], per_page: 25)
      @projects = @pagination.records
    end

    def show
      @project = policy_scope(Project).find(params[:id])
      authorize @project
      @milestones = @project.project_milestones.where.not(kind: %w[technical_review report_release])
      @events = @project.schedule_events.client_visible.order(:starts_at)
      @updates = @project.project_updates.client_visible.recent_first.limit(20)
      @progress = @project.progress_summary
    end
  end
end
