module PortalAccess
  extend ActiveSupport::Concern

  private
    def require_staff_portal_access
      deny_unless_membership! do |membership|
        membership.staff_domain?
      end
    end

    def require_client_portal_access
      deny_unless_membership! do |membership|
        membership.client_domain?
      end
    end

    def deny_unless_membership!
      unless Current.user
        redirect_to new_session_path
        return
      end

      membership = resolved_membership
      unless membership&.portal_access? && membership.user_id == Current.user.id
        redirect_to workspace_selection_path, alert: "Choose a workspace to continue."
        return
      end

      unless yield(membership)
        redirect_to root_path, alert: "You do not have access to this area."
        return
      end

      Current.membership = membership
      Current.session.update!(membership: membership) if Current.session.membership_id != membership.id
    end

    def resolved_membership
      candidate = Current.session&.membership
      return candidate if candidate && candidate.user_id == Current.user.id && candidate.portal_access?

      nil
    end
end
