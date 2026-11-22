module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      return unless (session_record = find_session_by_cookie)

      Current.session = session_record
      load_membership_context
      session_record.touch_activity!
      true
    end

    def find_session_by_cookie
      return unless cookies.signed[:session_id]

      session_record = Session.find_by(id: cookies.signed[:session_id])
      return unless session_record&.usable?

      session_record
    end

    def load_membership_context
      membership = Current.session.membership
      return unless membership

      if membership.portal_access? && membership.user_id == Current.user.id
        refresh_permission_epoch_if_needed!(membership)
        Current.membership = membership
      else
        clear_membership_context
      end
    end

    def refresh_permission_epoch_if_needed!(membership)
      return unless Current.session.permission_epoch_stale?(membership)

      Current.session.sync_permission_epoch_from!(membership)
    end

    def clear_membership_context
      Current.membership = nil
      Current.session&.update!(membership_id: nil) if Current.session&.membership_id.present?
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || default_post_login_path
    end

    def default_post_login_path
      memberships = Current.user.portal_eligible_memberships
      staff = memberships.select { |m| m.organization.ant_marine? }
      client = memberships.select { |m| m.organization.client? }

      if staff.one? && client.empty?
        assign_session_membership!(staff.first)
        staff_root_path
      elsif client.one? && staff.empty?
        assign_session_membership!(client.first)
        client_root_path
      elsif memberships.many?
        workspace_selection_path
      elsif staff.any?
        workspace_selection_path
      elsif client.any?
        workspace_selection_path
      else
        root_path
      end
    end

    def assign_session_membership!(membership)
      Current.session.update!(membership: membership)
      Current.membership = membership
    end

    def start_new_session_for(user)
      membership = single_default_membership_for(user)
      session_record = Session.issue_for!(
        user: user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        membership: membership
      )
      Current.session = session_record
      Current.membership = membership
      cookies.signed.permanent[:session_id] = {
        value: session_record.id,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }
      session_record
    end

    def single_default_membership_for(user)
      eligible = user.portal_eligible_memberships.to_a
      eligible.one? ? eligible.first : nil
    end

    def terminate_session
      Current.session&.revoke!
      Current.session = nil
      Current.membership = nil
      cookies.delete(:session_id)
    end
end
