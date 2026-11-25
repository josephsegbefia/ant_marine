# frozen_string_literal: true

require "test_helper"
require "test_helpers/enquiry_test_helper"

class Clients::OnboardFromEnquiryTest < ActiveSupport::TestCase
  include EnquiryTestHelper

  setup do
    @actor = memberships(:ops_manager_membership)
    @inquiry = submit_enquiry!(company_name: "Onboard Target Ltd", contact_email: "new-client-#{SecureRandom.hex(4)}@example.com")
    triage!(@inquiry, :start_review, membership: @actor)
    triage!(@inquiry, :qualify, membership: @actor, note: "Scope confirmed")
  end

  test "creates organisation, links enquiry and issues invitation" do
    result = Clients::OnboardFromEnquiry.call(
      actor_membership: @actor,
      inquiry: @inquiry,
      params: {
        organization_mode: "create",
        organization_name: "Onboard Target Ltd",
        contact_name: "Ama Mensah",
        contact_email: @inquiry.contact_email,
        role_key: "client.client_member",
        confirm_organization: "1"
      }
    )

    assert_equal "Onboard Target Ltd", result.organization.name
    assert_equal result.organization.id, @inquiry.reload.client_organization_id
    assert_equal "pending", result.invitation.status
    assert_predicate result.raw_token, :present?
    assert AuditEvent.exists?(event_type: "enquiry.linked_to_client_organization", subject_type: "ServiceInquiry", subject_id: @inquiry.id)
    assert AuditEvent.exists?(event_type: "client_onboarding.completed", subject_type: "ServiceInquiry", subject_id: @inquiry.id)
  end

  test "requires confirmation" do
    assert_raises(Clients::OnboardFromEnquiry::Error) do
      Clients::OnboardFromEnquiry.call(
        actor_membership: @actor,
        inquiry: @inquiry,
        params: {
          organization_mode: "create",
          organization_name: "Onboard Target Ltd",
          contact_email: @inquiry.contact_email,
          role_key: "client.client_member",
          confirm_organization: "0"
        }
      )
    end
  end

  test "refuses unqualified enquiry" do
    other = submit_enquiry!(company_name: "Not Ready Ltd", contact_email: "not-ready-#{SecureRandom.hex(4)}@example.com")
    assert_raises(Clients::OnboardFromEnquiry::InvalidState) do
      Clients::OnboardFromEnquiry.call(
        actor_membership: @actor,
        inquiry: other,
        params: {
          organization_mode: "create",
          organization_name: "Not Ready Ltd",
          contact_email: other.contact_email,
          role_key: "client.client_member",
          confirm_organization: "1"
        }
      )
    end
  end
end
