# frozen_string_literal: true

require "test_helper"

module Public
  class ServiceInquiriesTest < ActionDispatch::IntegrationTest
    include EnquiryTestHelper

    setup { reset_enquiry_rate_limit! }

    test "anonymous visitor sees the four-step request form without signing in" do
      get public_enquiry_path

      assert_response :success
      assert_select "h1", text: "Request a quote"
      assert_select ".public-header__link--active", count: 0
      assert_select ".public-enquiry__step", count: 4
      assert_select "input[name='service_inquiry[service_choice]'][value=?]", services(:marine_surveys_published).slug
      assert_select "input[name='service_inquiry[service_choice]'][value=?]", "not_sure"
      assert_select "input[name='service_inquiry[service_choice]'][value=?]", services(:marine_surveys_draft).slug, count: 0
      assert_select "input[name=company_website]"
      assert_select "input[type=file]", count: 0
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_select "body", text: /You can request a quote without creating an account/
      assert_select '[data-controller="ant-date-picker"][data-ant-date-picker-min-value]'
      assert_select 'input[type=date][name="service_inquiry[preferred_date]"][id=service_inquiry_preferred_date]'
    end

    test "service page call to action preselects that published service" do
      service = services(:marine_surveys_published)
      get public_service_path(service.slug)
      assert_select ".public-page-banner a[href=?]", public_enquiry_path(service: service.slug), text: "Enquire about this service"

      get public_enquiry_path(service: service.slug)
      assert_select "input[name='service_inquiry[service_choice]'][value=?][checked]", service.slug
      assert_select ".public-enquiry__preselected", text: /#{service.public_title}/
    end

    test "unpublished or unknown service in the link is ignored" do
      get public_enquiry_path(service: services(:marine_surveys_draft).slug)
      assert_select "input[name='service_inquiry[service_choice]'][checked]", count: 0
      assert_select ".public-enquiry__preselected", count: 0
    end

    test "valid submission creates one enquiry and shows the reference without personal data in the URL" do
      params = enquiry_form_params

      assert_difference -> { ServiceInquiry.count } => 1, -> { AuditEvent.where(event_type: "service_inquiry.submitted").count } => 1 do
        post public_enquiry_path, params: params
      end

      inquiry = ServiceInquiry.order(:id).last
      assert_redirected_to public_enquiry_received_path
      assert_equal "/request-a-quote/received", URI(response.location).request_uri
      assert_equal organizations(:ant_marine), inquiry.organization
      assert_equal services(:marine_surveys_published), inquiry.service
      assert_equal "Published surveys", inquiry.service_title_snapshot
      assert_equal "submitted", inquiry.current_status
      assert_equal "public_form", inquiry.channel
      assert_nil inquiry.client_organization_id
      assert_match(/\AANT-ENQ-\d{4}-\d{5}\z/, inquiry.reference_number)
      assert_equal "ama@harbour.example", inquiry.contact_email

      audit = AuditEvent.where(event_type: "service_inquiry.submitted").last
      assert_equal inquiry.reference_number, audit.metadata["reference_number"]
      refute audit.metadata.values.map(&:to_s).any? { |value| value.include?("Ama") || value.include?("harbour") }
      refute inquiry.submission_metadata.to_s.include?("127.0.0.1")

      follow_redirect!
      assert_response :success
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_select ".public-enquiry-received__reference", text: inquiry.reference_number
      assert_select "body", text: /Published surveys/
      assert_select "body", text: /preferred date is a request, not a confirmed appointment/
      assert_select "body", text: /quote has been issued|booking is confirmed|surveyor|email has been sent/i, count: 0
    end

    test "repeated submission with the same token does not create a duplicate" do
      params = enquiry_form_params

      assert_difference -> { ServiceInquiry.count } => 1 do
        post public_enquiry_path, params: params
        post public_enquiry_path, params: params
      end
      assert_redirected_to public_enquiry_received_path
    end

    test "visitor can choose not sure and still submit" do
      assert_difference -> { ServiceInquiry.count } => 1 do
        post public_enquiry_path, params: enquiry_form_params(service_choice: "not_sure")
      end
      inquiry = ServiceInquiry.order(:id).last
      assert_nil inquiry.service
      assert_equal "Not sure yet — needs advice", inquiry.requested_service_label
    end

    test "missing required fields re-render with answers kept and the first incomplete step open" do
      params = enquiry_form_params(location: "", contact_email: "")

      assert_no_difference -> { ServiceInquiry.count } do
        post public_enquiry_path, params: params
      end

      assert_response :unprocessable_content
      assert_select "[data-enquiry-wizard-step-value='2']"
      assert_select ".public-enquiry__alert li", minimum: 2
      assert_select "#service_inquiry_company_name[value=?]", "Harbour Logistics Ltd"
      assert_select "#service_inquiry_description", text: /underwater hull inspection/
      assert_select "#service_inquiry_location[aria-invalid=true]"
      assert_select "input[name=submission_token][value=?]", params[:submission_token]
    end

    test "forged, unpublished or foreign services are rejected server-side" do
      foreign = Service.create!(organization: organizations(:acme_client), title: "Foreign", slug: "foreign-service",
                                category: "marine_surveys", status: "published", published_title: "Foreign")

      [ services(:marine_surveys_draft).slug, foreign.slug, "made-up-service", "" ].each do |choice|
        assert_no_difference -> { ServiceInquiry.count } do
          post public_enquiry_path, params: enquiry_form_params(service_choice: choice)
        end
        assert_response :unprocessable_content
        assert_select "[data-enquiry-wizard-step-value='1']"
        assert_select "#service-choice-error"
      end
    end

    test "overlong text and malformed contact details are rejected" do
      params = enquiry_form_params(description: "a" * 4001, contact_email: "not-an-email", contact_phone: "call me maybe")

      assert_no_difference -> { ServiceInquiry.count } do
        post public_enquiry_path, params: params
      end
      assert_response :unprocessable_content
      assert_select ".public-enquiry__alert", text: /under 4000 characters/
      assert_select ".public-enquiry__alert", text: /valid email address/
      assert_select ".public-enquiry__alert", text: /phone number/
    end

    test "submitted markup is stored as plain text and escaped on display" do
      post public_enquiry_path, params: enquiry_form_params(company_name: "<script>alert(1)</script> Ltd")
      follow_redirect!
      inquiry = ServiceInquiry.order(:id).last
      assert_equal "<script>alert(1)</script> Ltd", inquiry.company_name
      assert_no_match(/<script>alert/, response.body)
    end

    test "honeypot and too-fast submissions are not saved" do
      assert_no_difference -> { ServiceInquiry.count } do
        post public_enquiry_path, params: enquiry_form_params.merge(company_website: "http://spam.example")
        assert_response :unprocessable_content
        post public_enquiry_path, params: enquiry_form_params(opened_at: Time.current)
        assert_response :unprocessable_content
        post public_enquiry_path, params: enquiry_form_params.merge(form_stamp: "forged")
        assert_response :unprocessable_content
      end
      assert_select "#service_inquiry_company_name[value=?]", "Harbour Logistics Ltd"
    end

    test "submissions are rate limited per connection" do
      5.times { post public_enquiry_path, params: enquiry_form_params }
      assert_no_difference -> { ServiceInquiry.count } do
        post public_enquiry_path, params: enquiry_form_params
      end
      assert_response :too_many_requests
      assert_select ".public-enquiry__alert", text: /wait a few minutes/
    end

    test "confirmation page without a submission in this session redirects to the form" do
      get public_enquiry_received_path
      assert_redirected_to public_enquiry_path
    end

    test "confirmation shows only the enquiry submitted in this browser session" do
      other = submit_enquiry!(company_name: "Other Shipping Co")
      post public_enquiry_path, params: enquiry_form_params
      follow_redirect!
      assert_select "body", text: /#{other.reference_number}/, count: 0
    end

    test "personal details are filtered from request logs" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      filtered = filter.filter(enquiry_form_params.deep_stringify_keys)
      inquiry = filtered["service_inquiry"]
      %w[company_name contact_name contact_email contact_phone vessel_name project_name location description preferred_date].each do |key|
        assert_equal "[FILTERED]", inquiry[key], "#{key} should be filtered"
      end
      assert_equal "[FILTERED]", filtered["submission_token"]
    end
  end
end
