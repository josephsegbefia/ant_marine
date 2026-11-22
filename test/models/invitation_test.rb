# frozen_string_literal: true

require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "find_by_token locates pending invitation" do
    invitation = Invitation.find_by_token!(FIXTURE_STAFF_TOKEN)
    assert_equal invitations(:pending_staff_invite).id, invitation.id
  end

  test "expired pending invitation is marked expired" do
    assert_raises(Invitation::UnusableInvitation) do
      Invitation.find_by_token!(FIXTURE_EXPIRED_TOKEN)
    end
    assert_equal "expired", invitations(:expired_client_invite).reload.status
  end

  test "token is not stored in plaintext" do
    invitation = invitations(:pending_staff_invite)
    assert_not_equal FIXTURE_STAFF_TOKEN, invitation.token_digest
    assert Invitations::Token.matches?(FIXTURE_STAFF_TOKEN, invitation.token_digest)
  end
end
