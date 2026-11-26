# frozen_string_literal: true

module Staff
  class ProjectScheduleEventsController < BaseController
    before_action :set_project

    def create
      authorize @project, :manage?
      Delivery::Schedule.propose!(
        actor: Current.membership,
        project: @project,
        attrs: event_params.to_h.symbolize_keys,
        conflict_override: params[:conflict_override],
        conflict_reason: params[:conflict_reason]
      )
      redirect_to staff_project_path(@project, tab: "schedule"), notice: "Activity proposed."
    rescue Delivery::Schedule::Denied, Delivery::Schedule::Error, Delivery::Schedule::Conflict => e
      redirect_to staff_project_path(@project, tab: "schedule"), alert: e.message
    end

    def confirm
      authorize @project, :manage?
      event = @project.schedule_events.find(params[:id])
      Delivery::Schedule.confirm!(actor: Current.membership, event: event)
      redirect_to staff_project_path(@project, tab: "schedule"), notice: "Activity confirmed."
    rescue Delivery::Schedule::Denied, Delivery::Schedule::Error => e
      redirect_to staff_project_path(@project, tab: "schedule"), alert: e.message
    end

    def cancel
      authorize @project, :manage?
      event = @project.schedule_events.find(params[:id])
      Delivery::Schedule.cancel!(actor: Current.membership, event: event, reason: params.require(:reason))
      redirect_to staff_project_path(@project, tab: "schedule"), notice: "Activity cancelled."
    rescue Delivery::Schedule::Denied, Delivery::Schedule::Error, ActionController::ParameterMissing => e
      redirect_to staff_project_path(@project, tab: "schedule"), alert: e.message
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end

      def event_params
        params.require(:schedule_event).permit(
          :title, :activity_type, :location, :starts_at, :ends_at,
          :responsible_membership_id, :internal_notes
        )
      end
  end
end
