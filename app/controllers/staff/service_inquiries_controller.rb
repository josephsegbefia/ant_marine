# frozen_string_literal: true

module Staff
  class ServiceInquiriesController < BaseController
    PER_PAGE = 25
    VIEWS = %w[all mine unassigned awaiting closed].freeze
    TEAM_VIEWS = %w[mine unassigned].freeze
    TRANSITION_NOTICES = {
      "start_review" => "Review started. You are now responsible for this enquiry if nobody else was.",
      "qualify" => "Marked ready to quote.",
      "mark_outside_scope" => "Marked outside our scope. The enquiry is now closed.",
      "mark_duplicate" => "Marked as a duplicate. The original request is kept unchanged.",
      "close" => "Enquiry closed.",
      "reopen" => "Enquiry reopened and returned to review."
    }.freeze

    before_action :set_inquiry, only: %i[show prepare_quotation transition assign]

    def index
      authorize ServiceInquiry
      assign_staff_breadcrumb(crumbs: [], current: "Enquiries")
      base = policy_scope(ServiceInquiry)
      @team_view = permitted?("inquiries.view_all")
      @view = VIEWS.include?(params[:view]) ? params[:view] : "all"
      @view = "all" if !@team_view && TEAM_VIEWS.include?(@view)
      @counts = summary_counts(base)
      @assignees = @team_view ? Intake::InquiryAssignment.eligible_memberships(Current.membership.organization).to_a : []
      @filters = filter_params
      scope = apply_filters(apply_view(base))
      @pagination = Pagination.new(
        scope.recent_first.includes(:service, assigned_membership: :user, quotes: :quote_deliveries),
        page: params[:page], per_page: PER_PAGE
      )
    end

    def show
      authorize @inquiry
      assign_staff_breadcrumb(crumbs: [ { label: "Enquiries", path: staff_service_inquiries_path } ],
                              current: @inquiry.reference_number)
      @inquiry_policy = policy(@inquiry)
      @open_quote = @inquiry.open_quote
      @quotes = @inquiry.quotes.includes(:quote_deliveries).order(:created_at)
      @actions = Intake::InquiryTransition.available_actions(@inquiry, Current.membership)
      @assignees = @inquiry_policy.assign? ? Intake::InquiryAssignment.eligible_memberships(Current.membership.organization).to_a : []
      @client_organizations = @actions.include?("qualify") ? Quote.assignable_client_organizations(Current.membership.organization).order(:name) : []
      @notes = @inquiry.notes.includes(:correction, author_membership: :user).order(:created_at)
      @clarifications = @inquiry.clarifications.includes(
        created_by_membership: :user, contacted_by_membership: :user, response_recorded_by_membership: :user
      ).order(:created_at)
      @duplicate_candidates = @inquiry.open? && @inquiry_policy.triage? ? Intake::DuplicateFinder.candidates(@inquiry, Current.membership) : []
      @duplicates = policy_scope(ServiceInquiry).where(duplicate_of_id: @inquiry.id).order(:submitted_at)
      @timeline = Intake::InquiryTimeline.entries(@inquiry)
    end

    def prepare_quotation
      authorize @inquiry
      result = Commercial::QuoteFromInquiry.call(inquiry: @inquiry, membership: Current.membership)
      notice = if result.created
                 "Draft quotation started from #{@inquiry.reference_number}. Add the scope, pricing and terms."
      else
                 "This enquiry already has a quotation in progress. Opened the existing quotation."
      end
      redirect_to edit_staff_quotation_path(result.quote, editor_step: 1), notice: notice
    rescue Commercial::QuoteFromInquiry::NotEligible, Commercial::QuoteFromInquiry::NotAuthorized => e
      redirect_to staff_service_inquiry_path(@inquiry), alert: e.message
    end

    def transition
      authorize @inquiry, :triage?
      step = params[:step].to_s
      unless Intake::InquiryTransition::STAFF_ACTIONS.include?(step)
        raise Intake::InquiryTransition::InvalidTransition, "That action is not available."
      end

      Intake::InquiryTransition.apply!(
        inquiry: @inquiry, action: step, membership: Current.membership,
        expected_lock_version: params[:expected_lock_version],
        attributes: params.permit(:note, :reason, :closure_reason, :duplicate_reference, :client_organization_id).to_h
      )
      redirect_to staff_service_inquiry_path(@inquiry), notice: TRANSITION_NOTICES.fetch(step)
    rescue Intake::InquiryTransition::InvalidTransition => e
      redirect_to staff_service_inquiry_path(@inquiry), alert: e.message
    end

    def assign
      authorize @inquiry, :assign?
      Intake::InquiryAssignment.assign!(
        inquiry: @inquiry, membership: Current.membership,
        assignee_id: params[:assignee_id], reason: params[:reason],
        expected_lock_version: params[:expected_lock_version]
      )
      @inquiry.reload
      notice = if @inquiry.assigned_membership
                 "#{Intake::InquiryAssignment.display_name(@inquiry.assigned_membership)} is now responsible for this enquiry."
      else
                 "Nobody is responsible for this enquiry now."
      end
      redirect_to staff_service_inquiry_path(@inquiry), notice: notice
    rescue Intake::InquiryTransition::InvalidTransition => e
      redirect_to staff_service_inquiry_path(@inquiry), alert: e.message
    end

    private

      def set_inquiry
        @inquiry = policy_scope(ServiceInquiry).find(params[:id])
      end

      def permitted?(key)
        Authorization::EffectivePermissions.new(Current.membership).allowed?(key)
      end

      def summary_counts(base)
        me = Current.membership.id
        {
          new: base.where(current_status: "submitted").count,
          mine: base.open_requests.where(assigned_membership_id: me).count,
          unassigned: base.open_requests.unassigned.count,
          awaiting: base.where(current_status: "needs_clarification").count,
          ready: base.where(current_status: "qualified").count
        }
      end

      def apply_view(scope)
        case @view
        when "mine" then scope.open_requests.where(assigned_membership_id: Current.membership.id)
        when "unassigned" then scope.open_requests.unassigned
        when "awaiting" then scope.where(current_status: "needs_clarification")
        when "closed" then scope.closed_or_resolved
        else scope
        end
      end

      def filter_params
        {
          q: params[:q].to_s.strip.first(100).presence,
          status: (params[:status] if ServiceInquiry::STATUSES.include?(params[:status])),
          assignee: assignee_filter,
          from: parse_date(params[:from]),
          to: parse_date(params[:to])
        }
      end

      def assignee_filter
        return nil unless @team_view
        return "unassigned" if params[:assignee] == "unassigned"

        params[:assignee] if @assignees.any? { |m| m.id.to_s == params[:assignee].to_s }
      end

      def parse_date(value)
        Date.iso8601(value.to_s) if value.present?
      rescue Date::Error
        nil
      end

      def apply_filters(scope)
        if @filters[:q]
          term = "%#{ActiveRecord::Base.sanitize_sql_like(@filters[:q])}%"
          scope = scope.where(
            "service_inquiries.reference_number ILIKE :term OR service_inquiries.company_name ILIKE :term OR " \
            "service_inquiries.contact_name ILIKE :term OR service_inquiries.contact_email ILIKE :term",
            term: term
          )
        end
        scope = scope.where(current_status: @filters[:status]) if @filters[:status]
        scope = case @filters[:assignee]
        when nil then scope
        when "unassigned" then scope.unassigned
        else scope.where(assigned_membership_id: @filters[:assignee])
        end
        scope = scope.where(submitted_at: @filters[:from].in_time_zone..) if @filters[:from]
        scope = scope.where(submitted_at: ..@filters[:to].in_time_zone.end_of_day) if @filters[:to]
        scope
      end
  end
end
