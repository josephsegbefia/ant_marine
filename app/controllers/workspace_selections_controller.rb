class WorkspaceSelectionsController < ApplicationController
  layout "access"

  def show
    @memberships = Current.user.portal_eligible_memberships.includes(:organization).order("organizations.name")
  end

  def update
    membership = Current.user.memberships.portal_eligible.find_by(id: params[:membership_id])

    unless membership
      redirect_to workspace_selection_path, alert: "That workspace is not available."
      return
    end

    Current.session.update!(membership: membership)
    Current.membership = membership

    if membership.staff_domain?
      redirect_to staff_root_path
    else
      redirect_to client_root_path
    end
  end
end
