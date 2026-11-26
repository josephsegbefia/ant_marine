# frozen_string_literal: true

module Staff
  class ProjectUpdatesController < BaseController
    before_action :set_project

    def create
      authorize @project, :publish_update?
      update = @project.project_updates.create!(
        author_membership: Current.membership,
        body: params.require(:body).to_s.strip,
        visibility: params[:visibility].presence_in(%w[client internal]) || "client",
        published_at: Time.current
      )
      audit = AuditEvent.record!(
        organization: @project.operating_organization,
        actor_membership: Current.membership,
        event_type: "project.update.published",
        subject: @project,
        metadata: { "project_update_id" => update.id, "visibility" => update.visibility }
      )
      if update.client_visible?
        # in-app staff copy only; no client push channel in F4-05 beyond portal read
        Notifications::StaffPublisher.publish_subject(
          Notifications::StaffPublisher.active_staff(@project.operating_organization).select { |m|
            Authorization::EffectivePermissions.new(m).allowed?("projects.view_all")
          },
          kind: "project_update",
          organization: @project.operating_organization,
          subject: @project,
          audit_event: audit,
          title: "Client update on #{@project.reference_number}"
        )
      end
      redirect_to staff_project_path(@project, tab: "activity"), notice: "Update recorded."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to staff_project_path(@project, tab: "activity"), alert: e.record.errors.full_messages.to_sentence
    end

    private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
      end
  end
end
