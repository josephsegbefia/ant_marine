# frozen_string_literal: true

module Client
  class QuotationsController < BaseController
    before_action :set_release, only: %i[show pdf decide create_decision]

    def index
      authorize QuotePortalRelease, :index?
      @releases = Clients::PortalQuoteVisibility.releases_for(membership: Current.membership)
      @pagination = Pagination.new(@releases, page: params[:page], per_page: 25)
      @releases = @pagination.records
    end

    def show
      authorize @release
      load_decision_context
    end

    def pdf
      authorize @release, :pdf?
      pdf = Commercial::QuotePdfRenderer.render(quote: @quote, revision: @revision)
      response.headers["Cache-Control"] = "private, no-store"
      filename = "#{@quote.reference_number}-v#{@revision.version_number}"
      filename += "-SIMULATED" if @release.simulated?
      send_data pdf, filename: "#{filename}.pdf", type: "application/pdf", disposition: "inline"
    end

    def decide
      authorize @release, :show?
      load_decision_context
      @decision_type = params[:type].to_s.presence_in(%w[accepted declined changes_requested])
      unless @decision_type && decision_allowed?(@decision_type)
        redirect_to client_quotation_path(@release), alert: "That decision is not available for your account."
      end
    end

    def create_decision
      authorize @release, :show?
      load_decision_context
      response_type = params.require(:decision).require(:response).to_s
      unless decision_allowed?(response_type)
        redirect_to client_quotation_path(@release), alert: "You are not authorised to make that decision."
        return
      end

      result = Commercial::QuoteDecision.call(
        membership: Current.membership,
        release: @release,
        response: response_type,
        reason: params.dig(:decision, :reason),
        confirmation: params.dig(:decision, :confirm),
        idempotency_key: params.dig(:decision, :idempotency_key).presence || SecureRandom.uuid
      )
      notice = if result.response.accepted?
        "Simulated acceptance recorded. This is not a binding commercial agreement."
      elsif result.response.declined?
        "Simulated decline recorded. This is not a binding commercial agreement."
      else
        "Your change request was recorded for the ANT Marine team."
      end
      redirect_to client_quotation_path(@release), notice: notice
    rescue Commercial::QuoteDecision::Denied => e
      redirect_to client_quotation_path(@release), alert: e.message
    rescue Commercial::QuoteDecision::InvalidState, Commercial::QuoteDecision::Conflict, Commercial::QuoteDecision::Error => e
      flash.now[:alert] = e.message
      @decision_type = response_type
      load_decision_context
      render :decide, status: :unprocessable_entity
    end

    private

      def set_release
        @release = Clients::PortalQuoteVisibility.find_release!(membership: Current.membership, release_id: params[:id])
        @quote = @release.quote
        @revision = @release.quote_revision
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      def load_decision_context
        @responses = QuoteResponse.where(quote_portal_release_id: @release.id).recent_first
        @terminal = @responses.detect(&:terminal?)
        @can_accept = decision_allowed?("accepted") && @terminal.nil?
        @can_decline = decision_allowed?("declined") && @terminal.nil?
        @can_request_changes = decision_allowed?("changes_requested") && @terminal.nil?
        @viewer_only = !@can_accept && !@can_decline && !@can_request_changes
      end

      def decision_allowed?(response_type)
        return false unless Commercial::QuoteDecision.available?
        return false unless @release&.active? && @release.simulated?

        policy = QuoteResponsePolicy.new(Current.membership, @release)
        case response_type
        when "accepted" then policy.accept?
        when "declined" then policy.decline?
        when "changes_requested" then policy.request_changes?
        else false
        end
      end
  end
end
