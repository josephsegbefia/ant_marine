# frozen_string_literal: true

module Staff
  class ClientsController < BaseController
    before_action :set_client, only: %i[show edit update suspend_membership revoke_membership create_contact archive_contact]

    def index
      authorize Organization, :index?
      @view = params[:view].presence_in(%w[awaiting with_portal pending_invites]) || "all"
      @filters = {
        q: params[:q].to_s.strip.presence,
        status: params[:status].presence_in(%w[active archived])
      }

      base = policy_scope(Organization).client
      scope = case @filters[:status]
      when "archived"
        base.where(status: "archived").order(:name)
      else
        base.active.order(:name)
      end

      if @filters[:q]
        term = "%#{ActiveRecord::Base.sanitize_sql_like(@filters[:q])}%"
        scope = scope.where(
          "organizations.name ILIKE :term OR organizations.reference_number ILIKE :term OR organizations.profile->>'business_email' ILIKE :term OR organizations.profile->>'primary_contact_name' ILIKE :term",
          term: term
        )
      end

      active_portal_ids = Membership.active.joins(:organization).merge(Organization.client).select(:organization_id)
      pending_invite_ids = Invitation.pending.joins(:organization).merge(Organization.client).select(:organization_id)

      scope = case @view
      when "awaiting"
        scope.where.not(id: active_portal_ids)
      when "with_portal"
        scope.where(id: active_portal_ids)
      when "pending_invites"
        scope.where(id: pending_invite_ids)
      else
        scope
      end

      active_scope = policy_scope(Organization).client.active
      @summary = {
        active: active_scope.count,
        awaiting: active_scope.where.not(id: active_portal_ids).count,
        pending_invites: Invitation.pending.joins(:organization).merge(Organization.client.active).count,
        with_portal: Membership.active.joins(:organization).merge(Organization.client.active).select(:organization_id).distinct.count
      }

      @pagination = Pagination.new(scope, page: params[:page], per_page: 25)
      @clients = @pagination.records
      ActiveRecord::Associations::Preloader.new(records: @clients, associations: [ :memberships, :invitations ]).call
      assign_staff_breadcrumb(crumbs: [], current: "Clients")
    end

    def show
      authorize @client
      @memberships = @client.memberships.includes(:user).order(Arel.sql("CASE status WHEN 'active' THEN 0 WHEN 'invited' THEN 1 WHEN 'suspended' THEN 2 ELSE 3 END"), :created_at)
      @contacts = @client.client_contacts.active.order(:full_name)
      @invitations = @client.invitations.order(created_at: :desc).limit(20)
      @decisions = QuoteResponse.where(client_organization_id: @client.id).includes(:quote, :quote_revision, :responded_by_user).recent_first.limit(20)
      @inquiries = ServiceInquiry.where(client_organization_id: @client.id).recent_first.limit(20)
      @quotes = Quote.where(client_organization_id: @client.id).recent_first.limit(20)
      @releases = QuotePortalRelease.where(client_organization_id: @client.id).includes(:quote, :quote_revision).order(released_at: :desc).limit(20)
      @activity = AuditEvent.where(subject_type: "Organization", subject_id: @client.id)
                            .or(AuditEvent.where("metadata->>'client_organization_id' = ?", @client.id.to_s))
                            .order(occurred_at: :desc).limit(30)
      @tab = params[:tab].presence_in(%w[overview access requests quotations activity]) || "overview"
      assign_staff_breadcrumb(crumbs: [ { label: "Clients", path: staff_clients_path } ], current: @client.name)
    end

    def new
      authorize Organization, :new?
      @client = Organization.new(kind: "client", status: "active")
      @duplicates = []
      assign_staff_breadcrumb(crumbs: [ { label: "Clients", path: staff_clients_path } ], current: "New client")
    end

    def create
      authorize Organization, :create?
      result = Clients::CreateOrganization.call(actor_membership: Current.membership, attributes: client_params)
      redirect_to staff_client_path(result.organization), notice: "Client organisation created."
    rescue Clients::CreateOrganization::Denied
      redirect_to staff_clients_path, alert: "You are not allowed to create client organisations."
    rescue Clients::CreateOrganization::Error => e
      @client = Organization.new(kind: "client", status: "active", name: client_params[:name])
      @duplicates = Organization.duplicate_suggestions(name: client_params[:name], email: client_params[:business_email])
      flash.now[:alert] = e.message
      assign_staff_breadcrumb(crumbs: [ { label: "Clients", path: staff_clients_path } ], current: "New client")
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @client
      assign_staff_breadcrumb(
        crumbs: [ { label: "Clients", path: staff_clients_path }, { label: @client.name, path: staff_client_path(@client) } ],
        current: "Edit"
      )
    end

    def update
      authorize @client
      Clients::UpdateOrganization.call(actor_membership: Current.membership, organization: @client, attributes: client_params)
      redirect_to staff_client_path(@client), notice: "Organisation details updated."
    rescue Clients::UpdateOrganization::Denied
      redirect_to staff_client_path(@client), alert: "You are not allowed to edit this organisation."
    rescue Clients::UpdateOrganization::Error => e
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    def suspend_membership
      authorize @client, :manage_access?
      membership = @client.memberships.find(params.require(:membership_id))
      Clients::MembershipLifecycle.suspend!(actor_membership: Current.membership, membership: membership)
      redirect_to staff_client_path(@client, tab: "access"), notice: "Portal access suspended."
    rescue Clients::MembershipLifecycle::Denied
      redirect_to staff_client_path(@client, tab: "access"), alert: "You are not allowed to suspend this membership."
    end

    def revoke_membership
      authorize @client, :manage_access?
      membership = @client.memberships.find(params.require(:membership_id))
      Clients::MembershipLifecycle.revoke!(actor_membership: Current.membership, membership: membership)
      redirect_to staff_client_path(@client, tab: "access"), notice: "Portal access revoked."
    rescue Clients::MembershipLifecycle::Denied
      redirect_to staff_client_path(@client, tab: "access"), alert: "You are not allowed to revoke this membership."
    end

    def create_contact
      authorize @client, :update?
      Clients::ManageContact.create!(
        actor_membership: Current.membership,
        organization: @client,
        attributes: contact_params
      )
      redirect_to staff_client_path(@client, tab: "access"), notice: "Business contact added."
    rescue Clients::ManageContact::Denied
      redirect_to staff_client_path(@client, tab: "access"), alert: "You are not allowed to manage contacts."
    rescue Clients::ManageContact::Error => e
      redirect_to staff_client_path(@client, tab: "access"), alert: e.message
    end

    def archive_contact
      authorize @client, :update?
      contact = @client.client_contacts.find(params.require(:contact_id))
      Clients::ManageContact.archive!(actor_membership: Current.membership, contact: contact)
      redirect_to staff_client_path(@client, tab: "access"), notice: "Contact archived."
    rescue Clients::ManageContact::Denied
      redirect_to staff_client_path(@client, tab: "access"), alert: "You are not allowed to manage contacts."
    end

    private

      def set_client
        @client = policy_scope(Organization).find(params[:id])
      end

      def contact_params
        params.require(:client_contact).permit(:full_name, :email, :phone, :job_title, :notes)
      end

      def client_params
        params.require(:organization).permit(
          :name, :trading_name, :business_email, :business_phone, :address, :country, :website,
          :registration_info, :primary_contact_name, :primary_contact_email, :primary_contact_phone
        )
      end
  end
end
