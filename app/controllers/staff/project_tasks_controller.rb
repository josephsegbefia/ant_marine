# frozen_string_literal: true

module Staff
  class ProjectTasksController < BaseController
    before_action :set_project

    def create
      authorize @project, :manage?
      Delivery::Tasks.create!(actor: Current.membership, project: @project, attrs: task_params)
      redirect_to staff_project_path(@project, tab: "tasks"), notice: "Task created."
    rescue Delivery::Tasks::Denied, Delivery::Tasks::Error => e
      redirect_to staff_project_path(@project, tab: "tasks"), alert: e.message
    end

    def update
      authorize @project, :manage?
      task = @project.tasks.find(params[:id])
      Delivery::Tasks.update!(actor: Current.membership, task: task, attrs: task_params.to_h.symbolize_keys)
      redirect_to staff_project_path(@project, tab: "tasks"), notice: "Task updated."
    rescue Delivery::Tasks::Denied, Delivery::Tasks::Error => e
      redirect_to staff_project_path(@project, tab: "tasks"), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end

      def task_params
        params.require(:task).permit(:title, :description, :assignee_membership_id, :priority, :due_on, :status, :notes)
      end
  end
end
