# frozen_string_literal: true

module Staff
  class QuotationsController < BaseController
    before_action :set_ant_marine_organization
    before_action :set_quote, except: %i[index new create]
    before_action :set_revision, only: %i[edit update submit_for_review return_for_correction approve issue withdraw pdf]

    STEPS = {
      1 => :client,
      2 => :scope,
      3 => :pricing,
      4 => :terms,
      5 => :review
    }.freeze

    def index
      authorize Quote
      @quotes = scoped_quotes
      apply_filters!
    end

    def show
      authorize @quote, :show?
      redirect_to edit_staff_quotation_path(@quote, editor_step: review_step)
    end

    def new
      authorize Quote, :new?
    end

    def create
      authorize Quote, :create?
      quote = Commercial::QuoteBuilder.create!(organization: @organization, membership: Current.membership)
      redirect_to edit_staff_quotation_path(quote, editor_step: 1), notice: "Draft quotation started."
    end

    def edit
      authorize @quote, :edit?
      assign_editor_lookups!
      @editor_step = editor_step_param
    end

    def assign_editor_lookups!
      @client_organizations = Organization.client.active.order(:name)
      @services = policy_scope(Service).published_catalogue.order(:title)
    end

    def update
      authorize @quote, :update?
      @editor_step = editor_step_param

      unless @quote.editable?
        redirect_to edit_staff_quotation_path(@quote), alert: "This quotation cannot be edited in its current state."
        return
      end

      @quote.assign_attributes(quote_shell_params)
      @quote.updated_by_membership = Current.membership
      @revision.assign_attributes(revision_params)

      if @revision.save
        @quote.save!
        redirect_after_save
      else
        assign_editor_lookups!
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_staff_quotation_path(@quote), alert: "Someone else updated this quotation. Refresh and try again."
    end

    def submit_for_review
      authorize @quote, :submit_for_review?
      Commercial::QuoteTransition.apply!(quote: @quote, action: :submit_for_review, membership: Current.membership)
      redirect_to edit_staff_quotation_path(@quote, editor_step: review_step), notice: "Quotation submitted for review."
    rescue Commercial::QuoteTransition::InvalidTransition
      redirect_to edit_staff_quotation_path(@quote), alert: "This quotation cannot be submitted right now."
    end

    def return_for_correction
      authorize @quote, :return_for_correction?
      Commercial::QuoteTransition.apply!(
        quote: @quote,
        action: :return_for_correction,
        membership: Current.membership,
        reason: params[:reason]
      )
      redirect_to edit_staff_quotation_path(@quote, editor_step: 1), notice: "Quotation returned for correction."
    rescue Commercial::QuoteTransition::InvalidTransition
      redirect_to edit_staff_quotation_path(@quote), alert: "This quotation cannot be returned right now."
    end

    def approve
      authorize @quote, :approve?
      Commercial::QuoteTransition.apply!(quote: @quote, action: :approve, membership: Current.membership)
      redirect_to edit_staff_quotation_path(@quote, editor_step: review_step), notice: "Quotation approved for issuance."
    rescue Commercial::QuoteTransition::InvalidTransition
      redirect_to edit_staff_quotation_path(@quote), alert: "This quotation cannot be approved right now."
    end

    def issue
      authorize @quote, :issue?
      Commercial::QuoteTransition.apply!(quote: @quote, action: :issue, membership: Current.membership)
      redirect_to edit_staff_quotation_path(@quote, editor_step: review_step),
                  notice: "Quotation marked as issued. Client delivery remains gated until F4-02B."
    rescue Commercial::QuoteTransition::InvalidTransition
      redirect_to edit_staff_quotation_path(@quote), alert: "This quotation cannot be issued right now."
    end

    def withdraw
      authorize @quote, :withdraw?
      Commercial::QuoteTransition.apply!(quote: @quote, action: :withdraw, membership: Current.membership)
      redirect_to staff_quotations_path, notice: "Quotation withdrawn."
    rescue Commercial::QuoteTransition::InvalidTransition
      redirect_to edit_staff_quotation_path(@quote), alert: "This quotation cannot be withdrawn right now."
    end

    def pdf
      authorize @quote, :pdf?
      pdf = Commercial::QuotePdfRenderer.render(quote: @quote)
      send_data pdf,
                filename: "#{@quote.reference_number}-v#{@revision.version_number}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

    private

      def set_ant_marine_organization
        @organization = Organization.ant_marine!
      end

      def set_quote
        @quote = policy_scope(Quote).find(params[:id])
      end

      def set_revision
        @revision = @quote.current_revision
      end

      def scoped_quotes
        policy_scope(Quote).includes(:current_revision, :client_organization).recent_first
      end

      def apply_filters!
        if params[:q].present?
          term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
          @quotes = @quotes.left_joins(:current_revision).where(
            "quotes.reference_number ILIKE :term OR quote_revisions.title ILIKE :term OR quotes.prospective_client->>'company_name' ILIKE :term",
            term: term
          )
        end
        return if params[:status].blank? || params[:status] == "all"

        @quotes = @quotes.where(status: params[:status])
      end

      def editor_step_param
        step = params[:editor_step].to_i
        step = 1 if step < 1
        step = 5 if step > 5
        step
      end

      def review_step
        5
      end

      def quote_shell_params
        params.require(:quote).permit(
          :client_organization_id,
          :service_id,
          :lock_version,
          prospective_client: %i[company_name contact_name email phone address]
        )
      end

      def revision_params
        params.require(:quote_revision).permit(
          :title,
          :scope_description,
          :deliverables,
          :exclusions,
          :additional_requirements,
          :currency,
          :valid_until,
          :payment_terms,
          :commercial_exclusions,
          :additional_conditions,
          :internal_notes,
          line_items_attributes: %i[id description quantity unit unit_price_cents _destroy]
        )
      end

      def redirect_after_save
        commit = params[:commit].to_s
        message = "Quotation saved."
        target_step = @editor_step

        if commit == "save_continue"
          target_step = [ @editor_step + 1, 5 ].min
          message = "Saved. You can continue to the next step."
        elsif commit == "review"
          target_step = review_step
          message = "Saved. Review the quotation before submitting."
        end

        redirect_to edit_staff_quotation_path(@quote, editor_step: target_step), notice: message
      end
  end
end
