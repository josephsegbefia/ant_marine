# frozen_string_literal: true

require "test_helper"

class InvitationsMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  test "invite email includes acceptance link" do
    invitation = invitations(:pending_staff_invite)
    email = InvitationsMailer.invite(invitation, FIXTURE_STAFF_TOKEN)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ invitation.email ], email.to
    assert_includes email.html_part.body.decoded, invitation_path(FIXTURE_STAFF_TOKEN)
    assert_includes email.text_part.body.decoded, invitation_path(FIXTURE_STAFF_TOKEN)
  end
end
