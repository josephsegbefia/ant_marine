# frozen_string_literal: true

module InvitationTestHelper
  FIXTURE_STAFF_TOKEN = "fixture-staff-invite-token"
  FIXTURE_EXPIRED_TOKEN = "fixture-expired-token"

  def issue_invitation!(inviter_membership:, organization:, email:, role_key:)
    Invitations::Issue.call(
      inviter_membership: inviter_membership,
      organization: organization,
      email: email,
      role_key: role_key
    )
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include InvitationTestHelper
end
