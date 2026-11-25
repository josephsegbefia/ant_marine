# frozen_string_literal: true

module Staff
  class QuotationsController < BaseController
    PER_PAGE = 25

    before_action :set_ant_marine_organization
    before_action :set_quote, except: %i[index new create]
    before_action :set_revision, only: %i[edit update pdf]
    before_action :set_breadcrumb, only: %i[index new edit update]

    STEPS = {
      1 => :client,
      2 => :scope,
      3 => :pricing,
      4 => :terms,
      5 => :review
    }.freeze

    LINE_ITEM_FIELDS = %i[id description quantity unit unit_choice unit_other unit_price position _destroy].freeze
    QUOTE_BOOKKEEPING_ATTRIBUTES = %w[updated_at updated_by_membership_id lock_version].freeze

    TRANSITION_NOTICES = {
      submit_for_review: "Quotation submitted for review.",
      return_for_correction: "Quotation returned to the preparer for correction.",
      approve: "Quotation approved. It has not been sent to the client.",
      withdraw: "Quotation withdrawn."
    }.freeze

    def index
      authorize Quote
      @quotes = scoped_quotes
      apply_filters!
      @filters = {
        q: params[:q].to_s.strip.presence,
        status: (params[:status].presence unless params[:status].blank? || params[:status] == "all")
      }
      @pagination = Pagination.new(@quotes, page: params[:page], per_page: PER_PAGE)
      @quotes = @pagination.records
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
      @editor_step = editor_step_param
      prepare_editor
    end

    def update
      authorize @quote, :update?
      @editor_step = editor_step_param

      assign_quote_attributes
      @revision.assign_attributes(revision_params)
      @quote.updated_by_membership = Current.membership
      @quote.updated_at = Time.current

      quote_valid = @quote.valid?
      revision_valid = @revision.valid?
      unless quote_valid && revision_valid
        render_editor_with_errors
        return
      end
      @revision.record_contributor(Current.membership) if material_change?

      Quote.transaction do
        @quote.save!
        @revision.save!
      end
      redirect_after_save
    rescue ActiveRecord::RecordInvalid
      render_editor_with_errors
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_staff_quotation_path(@quote, editor_step: @editor_step),
                  alert: "Someone else saved this quotation while you were editing. Your changes were not saved. " \
                         "Review the latest version and make your changes again."
    rescue ActiveRecord::RecordNotFound
      redirect_to edit_staff_quotation_path(@quote, editor_step: @editor_step),
                  alert: "Some pricing lines no longer match this quotation. Nothing was saved. Reload and try again."
    end

    def submit_for_review
      run_transition(:submit_for_review)
    end

    def return_for_correction
      run_transition(:return_for_correction, reason: params[:reason], success_step: 1)
    end

    def approve
      run_transition(:approve)
    end

    def issue
      run_transition(:issue)
    end

    def withdraw
      run_transition(:withdraw)
    end

    def create_revision
      authorize @quote, :show?
      revision = Commercial::QuoteRevisionCreator.create!(
        quote: @quote,
        membership: Current.membership,
        reason: params[:revision_reason],
        expected_version: { revision_id: params[:expected_revision_id], lock_version: params[:expected_lock_version] }
      )
      redirect_to edit_staff_quotation_path(@quote, editor_step: 2),
                  notice: "Version #{revision.version_number} started as a draft. " \
                          "Version #{revision.predecessor_revision.version_number} is unchanged and kept in the history."
    rescue Commercial::QuoteTransition::InvalidTransition => e
      redirect_to edit_staff_quotation_path(@quote, editor_step: review_step), alert: e.message
    end

    def version
      authorize @quote, :version?
      @version = @quote.quote_revisions.includes(:line_items, :prepared_by_membership, :approved_by_membership)
                       .find_by!(version_number: params[:version_number].to_i)
      assign_staff_breadcrumb(
        crumbs: [ { label: "Quotations", path: staff_quotations_path },
                  { label: @quote.reference_number, path: edit_staff_quotation_path(@quote) } ],
        current: "Version #{@version.version_number}"
      )
    end

    def pdf
      authorize @quote, :pdf?
      revision = params[:version].present? ? @quote.quote_revisions.find_by!(version_number: params[:version].to_i) : @revision
      pdf = Commercial::QuotePdfRenderer.render(quote: @quote, revision: revision)
      suffix = revision.version_frozen? ? "" : "-DRAFT"
      response.headers["Cache-Control"] = "private, no-store"
      send_data pdf,
                filename: "#{@quote.reference_number}-v#{revision.version_number}#{suffix}.pdf",
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

      def set_breadcrumb
        if action_name == "index"
          assign_staff_breadcrumb(crumbs: [], current: "Quotations")
        else
          assign_staff_breadcrumb(
            crumbs: [ { label: "Quotations", path: staff_quotations_path } ],
            current: @quote&.reference_number || "New quotation"
          )
        end
      end

      def prepare_editor
        @saved_quote ||= @quote
        @client_organizations = Quote.assignable_client_organizations(@organization).order(:name)
        @services = Quote.assignable_services(@organization).order(:title)
        @readiness = Commercial::QuoteReadiness.new(@saved_quote)
        @correction_request = @saved_quote.latest_correction_request if @saved_quote.status == "returned_for_correction"
      end

      def render_editor_with_errors
        @saved_quote = Quote.includes(current_revision: :line_items).find(@quote.id)
        prepare_editor
        @save_errors = (@quote.errors.map(&:message) + @revision.errors.map(&:message)).uniq
        flash.now[:alert] = "Nothing was saved. Check the highlighted details."
        render :edit, status: :unprocessable_entity
      end

      def run_transition(action, reason: nil, success_step: review_step)
        authorize @quote, :show?
        Commercial::QuoteTransition.apply!(
          quote: @quote,
          action: action,
          membership: Current.membership,
          reason: reason,
          expected_version: { revision_id: params[:expected_revision_id], lock_version: params[:expected_lock_version] }
        )
        redirect_to edit_staff_quotation_path(@quote, editor_step: success_step), notice: TRANSITION_NOTICES[action]
      rescue Commercial::QuoteTransition::NotReady => e
        redirect_to edit_staff_quotation_path(@quote, editor_step: review_step),
                    alert: "Not submitted. #{e.issues.size} #{'item'.pluralize(e.issues.size)} still " \
                           "#{e.issues.size == 1 ? 'needs' : 'need'} attention — see the checklist below."
      rescue Commercial::QuoteTransition::InvalidTransition => e
        redirect_to edit_staff_quotation_path(@quote, editor_step: review_step), alert: e.message
      end

      def material_change?
        (@quote.changed - QUOTE_BOOKKEEPING_ATTRIBUTES).any? ||
          @revision.changed? ||
          @revision.line_items.any? { |item| item.new_record? || item.changed? || item.marked_for_destruction? }
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
        params[:editor_step].to_i.clamp(1, 5)
      end

      def review_step
        5
      end

      def assign_quote_attributes
        attrs = params.fetch(:quote, {}).permit(
          :client_organization_id,
          :service_id,
          :lock_version,
          prospective_client: Quote::PROSPECTIVE_KEYS
        )
        @quote.lock_version = attrs[:lock_version] if attrs.key?(:lock_version)
        @quote.client_organization_id = attrs[:client_organization_id].presence if attrs.key?(:client_organization_id)
        @quote.service_id = attrs[:service_id].presence if attrs.key?(:service_id)
        return unless attrs.key?(:prospective_client)

        submitted = attrs[:prospective_client].to_h.transform_values { |value| value.to_s.strip.first(500) }
        @quote.prospective_client = (@quote.prospective_client || {}).merge(submitted).slice(*Quote::PROSPECTIVE_KEYS)
      end

      def revision_params
        params.fetch(:quote_revision, {}).permit(
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
          line_items_attributes: LINE_ITEM_FIELDS
        )
      end

      def redirect_after_save
        commit = params[:commit].to_s
        message = "Quotation saved."
        target_step = @editor_step

        if commit == "save_continue"
          target_step = [ @editor_step + 1, review_step ].min
          message = "Saved. Continue with the next step."
        elsif commit == "review"
          target_step = review_step
          message = "Saved. Review the quotation before submitting."
        end

        redirect_to edit_staff_quotation_path(@quote, editor_step: target_step), notice: message
      end
  end
end
