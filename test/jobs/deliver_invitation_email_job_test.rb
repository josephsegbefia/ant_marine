# frozen_string_literal: true

require "test_helper"

class DeliverInvitationEmailJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  setup do
    @invitation = invitations(:pending_staff_invite)
    @raw_token = FIXTURE_STAFF_TOKEN
    @sealed = Notifications::InvitationTokenSeal.seal(@raw_token, expires_at: @invitation.expires_at)
  end

  test "sends the invitation email to the invited address only" do
    assert_emails 1 do
      DeliverInvitationEmailJob.perform_now(@invitation.id, @sealed)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @invitation.email ], mail.to
    assert_includes mail.subject, @invitation.organization.name
    assert_includes mail.html_part.body.decoded, @raw_token
    assert_includes mail.text_part.body.decoded, @raw_token
    assert_equal "pending", @invitation.reload.status
  end

  test "job arguments do not contain the raw token" do
    job = DeliverInvitationEmailJob.new(@invitation.id, @sealed)

    assert_not_includes job.arguments.to_json, @raw_token
    assert_not DeliverInvitationEmailJob.log_arguments
  end

  test "revoked invitation is not emailed" do
    @invitation.revoke!

    assert_no_emails do
      DeliverInvitationEmailJob.perform_now(@invitation.id, @sealed)
    end
  end

  test "expired invitation is not emailed" do
    @invitation.update!(expires_at: 1.hour.ago)

    assert_no_emails do
      DeliverInvitationEmailJob.perform_now(@invitation.id, @sealed)
    end
  end

  test "repeating the job does not change the invitation record" do
    assert_no_changes -> { @invitation.reload.attributes.except("updated_at") } do
      2.times { DeliverInvitationEmailJob.perform_now(@invitation.id, @sealed) }
    end
  end

  test "a rolled back invitation is not enqueued" do
    assert_no_enqueued_jobs only: DeliverInvitationEmailJob do
      Invitation.transaction do
        Invitations::Issue.call(
          inviter_membership: memberships(:super_admin_membership),
          organization: organizations(:ant_marine),
          email: "rolled-back@example.com",
          role_key: "staff.general_staff"
        )
        raise ActiveRecord::Rollback
      end
    end

    assert_nil Invitation.find_by(email: "rolled-back@example.com")
  end

  test "temporary smtp failures are retried and permanent ones are discarded" do
    names = DeliverInvitationEmailJob.rescue_handlers.map(&:first)

    assert_includes names, "Net::SMTPServerBusy"
    assert_includes names, "Net::SMTPFatalError"
  end
end
