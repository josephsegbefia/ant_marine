# frozen_string_literal: true

module EnquiryTestHelper
  def enquiry_attributes(overrides = {})
    {
      company_name: "Harbour Logistics Ltd",
      contact_name: "Ama Mensah",
      contact_email: "ama@harbour.example",
      contact_phone: "+233 20 000 0000",
      project_name: "Annual hull survey",
      vessel_name: "MV Example",
      location: "Takoradi port",
      description: "We need an underwater hull inspection before our charter renewal.",
      preferred_date: (Date.current + 14).iso8601
    }.merge(overrides)
  end

  def enquiry_form_params(service_choice: services(:marine_surveys_published).slug, token: SecureRandom.urlsafe_base64(24),
                          opened_at: 30.seconds.ago, **overrides)
    {
      service_inquiry: enquiry_attributes(overrides).merge(service_choice: service_choice),
      submission_token: token,
      form_stamp: Intake::FormTiming.issue(opened_at),
      company_website: ""
    }
  end

  def submit_enquiry!(service_choice: services(:marine_surveys_published).slug, token: SecureRandom.urlsafe_base64(24), **overrides)
    Intake::InquirySubmission.submit!(
      attributes: enquiry_attributes(overrides),
      service_choice: service_choice,
      submission_token: token
    ).inquiry.tap { |inquiry| raise "Enquiry not saved: #{inquiry.errors.full_messages}" unless inquiry.persisted? }
  end

  def reset_enquiry_rate_limit!
    Rails.application.config.x.public_enquiry_rate_limit_store&.clear
  end
end
