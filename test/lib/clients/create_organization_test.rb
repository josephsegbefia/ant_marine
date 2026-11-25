# frozen_string_literal: true

require "test_helper"

class Clients::CreateOrganizationTest < ActiveSupport::TestCase
  setup do
    @actor = memberships(:ops_manager_membership)
  end

  test "creates a client organisation with reference and audit" do
    result = Clients::CreateOrganization.call(
      actor_membership: @actor,
      attributes: { name: "Harbour Partners Ltd", business_email: "ops@harbour.test", primary_contact_name: "Ama" }
    )

    org = result.organization
    assert org.client?
    assert org.active?
    assert_match(/\ACLT-\d{4}-\d{4}\z/, org.reference_number)
    assert_equal "Ama", org.primary_contact_name
    assert AuditEvent.exists?(event_type: "client_organization.created", subject_type: "Organization", subject_id: org.id)
  end

  test "denies staff without qualify permission" do
    assert_raises(Clients::CreateOrganization::Denied) do
      Clients::CreateOrganization.call(
        actor_membership: memberships(:staff_membership),
        attributes: { name: "Denied Co" }
      )
    end
  end

  test "requires a name" do
    assert_raises(Clients::CreateOrganization::Error) do
      Clients::CreateOrganization.call(actor_membership: @actor, attributes: { name: "  " })
    end
  end
end
