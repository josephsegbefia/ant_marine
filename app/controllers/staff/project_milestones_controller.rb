# frozen_string_literal: true

module Staff
  class ProjectMilestonesController < BaseController
    before_action :set_project

    def complete
      authorize @project, :manage?
      milestone = @project.project_milestones.find(params[:id])
      Delivery::Milestones.complete!(actor: Current.membership, milestone: milestone)
      redirect_to staff_project_path(@project, tab: "milestones"), notice: "Milestone marked complete."
    rescue Delivery::Milestones::Denied, Delivery::Milestones::Error => e
      redirect_to staff_project_path(@project, tab: "milestones"), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end
  end
end
