# frozen_string_literal: true

module Staff
  class InvoicesController < BaseController
    PER_PAGE = 25
    before_action :set_invoice, only: %i[show edit update issue release void download]

    def index
      authorize Invoice
      scope = policy_scope(Invoice).includes(:client_organization, :project, :payment_records)
      scope = apply_filters(scope)
      @summary = index_summary(policy_scope(Invoice))
      @pagination = Pagination.new(scope.recent_first, page: params[:page], per_page: PER_PAGE)
      @invoices = @pagination.records
      assign_staff_breadcrumb(crumbs: [ { label: "Finance", path: staff_finance_path } ], current: "Invoices")
    end

    def show
      authorize @invoice
      @payments = @invoice.payment_records.includes(:payment_reversal).recent_first
      @releases = @invoice.invoice_releases.order(released_at: :desc)
      assign_staff_breadcrumb(
        crumbs: [
          { label: "Finance", path: staff_finance_path },
          { label: "Invoices", path: staff_invoices_path }
        ],
        current: @invoice.reference_number
      )
    end

    def new
      authorize Invoice
      raise Pundit::NotAuthorizedError unless Billing::Access.can_manage?(Current.membership)

      @project = find_billable_project!
      @remaining = Billing::Capacity.remaining_billable_cents(@project, include_drafts: true)
      @accepted = Billing::Capacity.accepted_total_cents(@project)
      assign_staff_breadcrumb(
        crumbs: [
          { label: "Finance", path: staff_finance_path },
          { label: "Invoices", path: staff_invoices_path }
        ],
        current: "Create invoice"
      )
    end

    def create
      authorize Invoice
      raise Pundit::NotAuthorizedError unless Billing::Access.can_manage?(Current.membership)

      project = find_billable_project!
      result = Billing::CreateDraft.call(
        membership: Current.membership,
        project: project,
        attributes: invoice_params,
        lines: line_params,
        confirmation: params[:confirm]
      )
      redirect_to staff_invoice_path(result.invoice), notice: "Draft invoice #{result.invoice.reference_number} created."
    rescue Billing::CreateDraft::Denied, Billing::CreateDraft::InvalidState, Billing::CreateDraft::Error => e
      @project = project
      @remaining = Billing::Capacity.remaining_billable_cents(@project, include_drafts: true)
      @accepted = Billing::Capacity.accepted_total_cents(@project)
      flash.now[:alert] = e.message
      assign_staff_breadcrumb(
        crumbs: [
          { label: "Finance", path: staff_finance_path },
          { label: "Invoices", path: staff_invoices_path }
        ],
        current: "Create invoice"
      )
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @invoice
      @project = @invoice.project
      @remaining = Billing::Capacity.remaining_billable_cents(@project, excluding_invoice_id: @invoice.id, include_drafts: true)
      @accepted = Billing::Capacity.accepted_total_cents(@project)
    end

    def update
      authorize @invoice
      result = Billing::UpdateDraft.call(
        membership: Current.membership,
        invoice: @invoice,
        attributes: invoice_params,
        lines: line_params
      )
      redirect_to staff_invoice_path(result.invoice), notice: "Draft invoice updated."
    rescue Billing::UpdateDraft::Denied, Billing::UpdateDraft::InvalidState, Billing::UpdateDraft::Error => e
      @project = @invoice.project
      @remaining = Billing::Capacity.remaining_billable_cents(@project, excluding_invoice_id: @invoice.id, include_drafts: true)
      @accepted = Billing::Capacity.accepted_total_cents(@project)
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    def issue
      authorize @invoice, :issue?
      result = Billing::Issue.call(membership: Current.membership, invoice: @invoice, confirmation: params[:confirm])
      redirect_to staff_invoice_path(result.invoice), notice: "Invoice #{result.invoice.reference_number} issued (simulated)."
    rescue Billing::Issue::Denied, Billing::Issue::InvalidState, Billing::Issue::Error => e
      redirect_to staff_invoice_path(@invoice), alert: e.message
    end

    def release
      authorize @invoice, :release?
      result = Billing::Release.call(membership: Current.membership, invoice: @invoice, confirmation: params[:confirm])
      redirect_to staff_invoice_path(result.invoice), notice: "Invoice released to the client portal (simulated)."
    rescue Billing::Release::Denied, Billing::Release::InvalidState, Billing::Release::Error => e
      redirect_to staff_invoice_path(@invoice), alert: e.message
    end

    def void
      authorize @invoice, :void?
      result = Billing::VoidInvoice.call(
        membership: Current.membership,
        invoice: @invoice,
        reason: params[:reason],
        confirmation: params[:confirm]
      )
      redirect_to staff_invoice_path(result.invoice), notice: "Invoice voided."
    rescue Billing::VoidInvoice::Denied, Billing::VoidInvoice::InvalidState, Billing::VoidInvoice::Error => e
      redirect_to staff_invoice_path(@invoice), alert: e.message
    end

    def download
      authorize @invoice, :download?
      payload = Billing::SecureDownload.call(membership: Current.membership, invoice: @invoice)
      send_data payload.bytes,
                filename: payload.filename,
                type: payload.content_type,
                disposition: "attachment"
      response.headers["Cache-Control"] = "private, no-store"
    rescue Billing::SecureDownload::Denied, Billing::SecureDownload::InvalidState => e
      redirect_to staff_invoice_path(@invoice), alert: e.message
    end

    private

      # Finance officers may lack ProjectPolicy visibility; billing.manage authorizes
      # operating-organisation project lookup for invoice creation only.
      def find_billable_project!
        Project.for_operating_organization(Current.membership.organization)
               .find(params.require(:project_id))
      end

      def set_invoice
        @invoice = policy_scope(Invoice).find(params[:id])
      end

      def invoice_params
        params.fetch(:invoice, {}).permit(:description, :issue_on, :due_on, :payment_terms_text)
      end

      def line_params
        raw = params.fetch(:invoice, {}).permit(lines: %i[description quantity unit unit_amount quote_line_item_id])
        Array(raw[:lines])
      end

      def apply_filters(scope)
        scope = scope.where(issue_status: params[:issue_status]) if params[:issue_status].present?
        scope = scope.where(currency: params[:currency]) if params[:currency].present?
        scope = scope.where(client_organization_id: params[:client_id]) if params[:client_id].present?
        scope = scope.where(project_id: params[:project_id]) if params[:project_id].present?
        if params[:q].present?
          term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
          scope = scope.left_joins(:client_organization).where(
            "invoices.reference_number ILIKE :t OR organizations.name ILIKE :t",
            t: term
          )
        end
        if params[:payment_status] == "overdue"
          scope = scope.issued.where("due_on < ?", Time.zone.today)
        end
        scope
      end

      def index_summary(scope)
        {
          all: scope.count,
          draft: scope.draft.count,
          issued: scope.issued.count,
          void: scope.voided.count,
          overdue: scope.issued.where("due_on < ?", Time.zone.today).count
        }
      end
  end
end
