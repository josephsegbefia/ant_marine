# frozen_string_literal: true

module Staff
  class ProjectAssignmentsController < BaseController
    before_action :set_project

    def create
      authorize @project, :assign?
      result = Delivery::Assign.call(
        actor_membership: Current.membership,
        project: @project,
        membership: Membership.find(params.require(:membership_id)),
        assignment_kind: params.require(:assignment_kind),
        reason: params[:reason],
        access_scope: params[:access_scope]
      )
      redirect_to staff_project_path(@project, tab: "team"), notice: "#{result.assignment.kind_label} assigned."
    rescue Delivery::Assign::Denied, Delivery::Assign::Error => e
      redirect_to staff_project_path(@project, tab: "team"), alert: e.message
    end

    def destroy
      authorize @project, :assign?
      assignment = @project.assignments.find(params[:id])
      Delivery::Unassign.call(actor_membership: Current.membership, assignment: assignment, reason: params.require(:reason))
      redirect_to staff_project_path(@project, tab: "team"), notice: "Assignment removed."
    rescue Delivery::Unassign::Denied, Delivery::Unassign::Error, ActionController::ParameterMissing => e
      redirect_to staff_project_path(@project, tab: "team"), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end
  end
end
