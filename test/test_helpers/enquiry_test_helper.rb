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

  def create_staff_member!(role_key: "staff.surveyor", organization: organizations(:ant_marine), status: "active",
                           user_status: "active", name: "Kofi Surveyor")
    user = User.create!(email: "member-#{SecureRandom.hex(4)}@ant.example", password: "Secure-password-123",
                        full_name: name, status: user_status)
    Membership.create!(user: user, organization: organization, role_key: role_key, status: status, accepted_at: Time.current)
  end

  def triage!(inquiry, action, membership: memberships(:dual_staff), **attributes)
    Intake::InquiryTransition.apply!(inquiry: inquiry, action: action, membership: membership,
                                     expected_lock_version: ServiceInquiry.find(inquiry.id).lock_version,
                                     attributes: attributes)
  end

  def assign_enquiry!(inquiry, assignee, membership: memberships(:dual_staff), reason: nil)
    Intake::InquiryAssignment.assign!(inquiry: inquiry, membership: membership, assignee_id: assignee&.id,
                                      reason: reason, expected_lock_version: ServiceInquiry.find(inquiry.id).lock_version)
  end

  def reset_enquiry_rate_limit!
    Rails.application.config.x.public_enquiry_rate_limit_store&.clear
  end
end
