# frozen_string_literal: true

module DeliveryTestHelper
  def build_accepted_project!(staff: memberships(:ops_manager_membership),
                              client_org: organizations(:acme_client),
                              owner: memberships(:client_owner_membership),
                              idempotency_key: "f405-h1-#{SecureRandom.hex(4)}")
    quote = approve_quote!(create_ready_quote)
    quote.update_columns(client_organization_id: client_org.id)
    release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: staff,
      quote: quote,
      quote_revision: quote.current_revision,
      client_organization: client_org
    ).release
    response = Commercial::QuoteDecision.call(
      membership: owner,
      release: release,
      response: "accepted",
      confirmation: true,
      idempotency_key: idempotency_key
    ).response
    project = Delivery::CreateFromAcceptance.call(
      membership: staff,
      quote_response: response,
      confirmation: true
    ).project
    { quote: quote, release: release, response: response, project: project }
  end

  def create_staff_membership!(role_key:, email: nil, full_name: nil, password: "Secure-password-123")
    email ||= "#{role_key.tr('.', '-')}-#{SecureRandom.hex(3)}@example.com"
    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      status: "active",
      full_name: full_name || role_key.split(".").last.humanize
    )
    Membership.create!(
      user: user,
      organization: organizations(:ant_marine),
      role_key: role_key,
      status: "active",
      permission_epoch: 0,
      lock_version: 0,
      accepted_at: Time.current
    )
  end
end

ActiveSupport::TestCase.include DeliveryTestHelper
