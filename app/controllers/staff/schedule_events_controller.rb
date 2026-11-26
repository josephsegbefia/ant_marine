# frozen_string_literal: true

module Staff
  class ScheduleEventsController < BaseController
    def index
      authorize Project, :index?
      project_ids = policy_scope(Project).select(:id)
      scope = ScheduleEvent.where(project_id: project_ids)
                          .includes(project: :client_organization, responsible_membership: :user)
                          .order(:starts_at)
      @view = params[:view].presence_in(%w[upcoming mine confirmed proposed]) || "upcoming"
      scope = case @view
      when "mine" then scope.where(responsible_membership_id: Current.membership.id)
      when "confirmed" then scope.confirmed.upcoming
      when "proposed" then scope.where(confirmation_state: "proposed").upcoming
      else scope.upcoming
      end
      @pagination = Pagination.new(scope, page: params[:page], per_page: 25)
      @events = @pagination.records
      assign_staff_breadcrumb(crumbs: [], current: "Schedule")
    end
  end
end
