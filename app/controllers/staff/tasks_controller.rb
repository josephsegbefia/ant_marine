# frozen_string_literal: true

module Staff
  class TasksController < BaseController
    def index
      authorize Project, :index?
      project_ids = policy_scope(Project).select(:id)
      scope = Task.where(project_id: project_ids).includes(project: :client_organization, assignee_membership: :user)
      @view = params[:view].presence_in(%w[all mine upcoming overdue completed]) || "mine"
      scope = case @view
      when "mine" then scope.where(assignee_membership_id: Current.membership.id)
      when "upcoming" then scope.open.where.not(due_on: nil).where("due_on >= ?", Time.zone.today).order(:due_on)
      when "overdue" then scope.overdue.order(:due_on)
      when "completed" then scope.where(status: "completed").order(completed_at: :desc)
      else scope.order(:due_on, :id)
      end
      @pagination = Pagination.new(scope, page: params[:page], per_page: 25)
      @tasks = @pagination.records
      assign_staff_breadcrumb(crumbs: [], current: "My tasks")
    end
  end
end
