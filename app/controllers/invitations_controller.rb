# frozen_string_literal: true

class InvitationsController < ApplicationController
  layout "access"

  allow_unauthenticated_access
  before_action :set_invitation, only: %i[ show continue setup complete_setup ]
  rate_limit to: 20, within: 3.minutes, only: :complete_setup, with: -> { redirect_to invitation_setup_path(params[:token]), alert: "Try again in a few minutes." }

  def show
    @portal_label = portal_label_for(@invitation)
  end

  def continue
    redirect_to invitation_setup_path(params[:token])
  end

  def setup
    @existing_user = User.find_by(email: @invitation.email)
    @portal_label = portal_label_for(@invitation)

    if wrong_signed_in_user?
      flash.now[:alert] = "Sign in with #{@invitation.email} to accept this invitation."
    elsif @existing_user && !authenticated?
      session[:return_to_after_authenticating] = invitation_setup_path(params[:token])
      redirect_to new_session_path, notice: "Sign in with #{@invitation.email} to continue."
    end
  end

  def complete_setup
    if wrong_signed_in_user?
      flash.now[:alert] = "Sign in with #{@invitation.email} to accept this invitation."
      @existing_user = User.find_by(email: @invitation.email)
      @portal_label = portal_label_for(@invitation)
      return render :setup, status: :unprocessable_entity
    end

    actor = Current.user if authenticated?
    existing = User.find_by(email: @invitation.email)
    new_user_params = existing ? nil : setup_params

    result = ::Invitations::Accept.call(
      invitation: @invitation,
      actor_user: actor,
      new_user_params: new_user_params
    )

    if actor
      assign_session_membership!(result.membership) if Current.session
      redirect_to after_acceptance_path(result.membership), notice: "You have joined #{result.membership.organization.name}."
    else
      start_new_session_for(result.user)
      assign_session_membership!(result.membership)
      redirect_to after_acceptance_path(result.membership), notice: "Your account is ready. Welcome to ANT Marine."
    end
  rescue ::Invitations::Accept::Error => e
    flash.now[:alert] = e.message
    @existing_user = User.find_by(email: @invitation.email)
    @portal_label = portal_label_for(@invitation)
    render :setup, status: :unprocessable_entity
  end

  private

    def set_invitation
      digest = ::Invitations::Token.digest(params[:token].to_s)
      @invitation = Invitation.find_by(token_digest: digest)

      unless @invitation
        render :invalid
        return
      end

      @invitation.resolve_lifecycle!
      return if performed?

      unless @invitation.usable?
        render_unusable(@invitation.public_state)
      end
    end

    def setup_params
      params.permit(:full_name, :password, :password_confirmation)
    end

    def wrong_signed_in_user?
      authenticated? && Current.user.email != @invitation.email
    end

    def portal_label_for(invitation)
      if invitation.organization.ant_marine?
        "the ANT Marine staff workspace"
      else
        "the client portal for #{invitation.organization.name}"
      end
    end

    def render_unusable(reason)
      case reason
      when "expired"
        render :expired
      when "revoked"
        render :revoked
      when "accepted"
        render :already_accepted
      else
        render :invalid
      end
    end

    def after_acceptance_path(membership)
      if membership.staff_domain?
        staff_root_path
      elsif membership.client_domain?
        client_root_path
      else
        workspace_selection_path
      end
    end
end
