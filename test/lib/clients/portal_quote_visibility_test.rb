# frozen_string_literal: true

require "test_helper"

class Clients::PortalQuoteVisibilityTest < ActiveSupport::TestCase
  setup do
    @actor = memberships(:ops_manager_membership)
    @client_org = organizations(:acme_client)
    @other_org = organizations(:other_client)
    @member = memberships(:client_membership)
    @quote = approve_quote!(create_ready_quote)
    @quote.update_columns(client_organization_id: @client_org.id)
  end

  test "organisation linkage alone does not expose a quotation" do
    releases = Clients::PortalQuoteVisibility.releases_for(membership: @member)
    assert_empty releases
  end

  test "simulated portal release exposes exact version to matching client" do
    revision = @quote.current_revision
    release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @actor,
      quote: @quote,
      quote_revision: revision,
      client_organization: @client_org
    ).release

    visible = Clients::PortalQuoteVisibility.releases_for(membership: @member)
    assert_includes visible.map(&:id), release.id
    assert_equal revision.id, visible.first.quote_revision_id
    assert release.simulated?
  end

  test "other client organisation cannot see the release" do
    Clients::ReleaseQuoteToPortal.call(
      actor_membership: @actor,
      quote: @quote,
      quote_revision: @quote.current_revision,
      client_organization: @client_org
    )

    other_user = User.create!(
      email: "other-portal-#{SecureRandom.hex(3)}@example.com",
      password: "Secure-password-123",
      full_name: "Other Client",
      status: "active"
    )
    other_membership = Membership.create!(
      user: other_user,
      organization: @other_org,
      role_key: "client.client_member",
      status: "active",
      accepted_at: Time.current
    )

    assert_empty Clients::PortalQuoteVisibility.releases_for(membership: other_membership)
  end

  test "production refuses simulated release" do
    original_env = Rails.env
    Rails.env = "production"
    assert_raises(Clients::ReleaseQuoteToPortal::Error) do
      Clients::ReleaseQuoteToPortal.call(
        actor_membership: @actor,
        quote: @quote,
        quote_revision: @quote.current_revision,
        client_organization: @client_org
      )
    end
  ensure
    Rails.env = original_env if original_env
  end
end
