# frozen_string_literal: true

module Public
  class ServiceInquiriesController < BaseController
    PERMITTED = %i[company_name contact_name contact_email contact_phone project_name vessel_name
                   location description preferred_date].freeze
    SESSION_KEY = :received_service_inquiry_id

    before_action :prevent_caching

    rate_limit to: 5, within: 10.minutes, only: :create,
               store: Rails.application.config.x.public_enquiry_rate_limit_store || Rails.cache,
               with: -> { reject_submission(:too_many_requests, rate_limit_message) }

    def new
      @inquiry = ServiceInquiry.new(service_choice: preselected_service_slug)
      @step = 1
      prepare_form
    end

    def create
      return reject_submission(:unprocessable_content, spam_message) unless genuine_submission?

      result = Intake::InquirySubmission.submit!(
        attributes: inquiry_params,
        service_choice: params.dig(:service_inquiry, :service_choice),
        submission_token: params[:submission_token],
        request_meta: request_meta
      )

      if result.saved?
        session[SESSION_KEY] = result.inquiry.id
        redirect_to public_enquiry_received_path, status: :see_other
      else
        @inquiry = result.inquiry
        @step = @inquiry.first_error_step
        prepare_form(submission_token: params[:submission_token])
        flash.now[:alert] = "Please check the highlighted details and send again."
        render :new, status: :unprocessable_content
      end
    end

    def received
      @inquiry = ServiceInquiry.find_by(id: session[SESSION_KEY])
      redirect_to public_enquiry_path unless @inquiry
    end

    private

      def inquiry_params
        params.fetch(:service_inquiry, {}).permit(*PERMITTED)
      end

      def published_services
        @published_services ||= Service.published_catalogue.for_ant_marine.to_a
      end

      def preselected_service_slug
        slug = params[:service].to_s
        published_services.find { |service| service.slug == slug }&.slug
      end

      def prepare_form(submission_token: nil)
        @services = published_services
        @submission_token = submission_token.presence || SecureRandom.urlsafe_base64(24)
        @form_stamp = Intake::FormTiming.issue
        @preselected_service = @services.find { |service| service.slug == @inquiry.service_choice }
      end

      def genuine_submission?
        params[:company_website].blank? && Intake::FormTiming.human_pace?(params[:form_stamp])
      end

      def reject_submission(status, message)
        @inquiry = ServiceInquiry.new(inquiry_params.merge(service_choice: params.dig(:service_inquiry, :service_choice)))
        @step = 4
        prepare_form(submission_token: params[:submission_token])
        flash.now[:alert] = message
        render :new, status: status
      end

      def spam_message
        "We could not send your request just yet. Please check your details and select “Send request” again."
      end

      def rate_limit_message
        "We have received several requests from this connection. Please wait a few minutes and try again, " \
          "or contact us directly."
      end

      def request_meta
        {
          "network_digest" => network_digest,
          "form_seconds" => Intake::FormTiming.elapsed_seconds(params[:form_stamp]),
          "entry_service" => params[:entry_service].to_s.first(80).presence
        }
      end

      def network_digest
        OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, request.remote_ip.to_s).first(20)
      end

      def prevent_caching
        response.headers["Cache-Control"] = "no-store"
      end
  end
end
