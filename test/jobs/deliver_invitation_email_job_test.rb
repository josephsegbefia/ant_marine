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

  test "serialized job payload does not expose the raw token" do
    assert_enqueued_jobs 1, only: DeliverInvitationEmailJob do
      Notifications::Dispatch.invitation!(invitation: @invitation, raw_token: @raw_token)
    end

    serialized = enqueued_jobs.last[:args].to_json
    assert_not_includes serialized, @raw_token
  end

  test "perform does not enqueue a second mail delivery job bearing the token" do
    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      DeliverInvitationEmailJob.perform_now(@invitation.id, @sealed)
    end
  end

  test "stale sealed token for a revoked invitation does not send mail" do
    Invitations::Resend.call(
      inviter_membership: memberships(:super_admin_membership),
      invitation: @invitation
    )

    assert_no_emails do
      DeliverInvitationEmailJob.perform_now(@invitation.id, @sealed)
    end

    assert_equal "revoked", @invitation.reload.status
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

  test "permanent smtp failure is discarded with instrumentation and without leaking the token" do
    smtp_error = Net::SMTPFatalError.new("550 permanent")
    failing_mail = Class.new do
      define_method(:deliver_now) { raise smtp_error }
    end.new

    discard_events = []
    callback = lambda do |*args|
      discard_events << ActiveSupport::Notifications::Event.new(*args)
    end

    log = StringIO.new
    old_logger = Rails.logger
    Rails.logger = Logger.new(log)

    original_invite = InvitationsMailer.method(:invite)

    begin
      InvitationsMailer.define_singleton_method(:invite) { |*_args| failing_mail }
      ActiveSupport::Notifications.subscribed(callback, "discard.active_job") do
        assert_nothing_raised do
          DeliverInvitationEmailJob.perform_now(@invitation.id, @sealed)
        end
      end
    ensure
      InvitationsMailer.define_singleton_method(:invite, original_invite)
      Rails.logger = old_logger
    end

    assert_equal 1, discard_events.size
    assert_equal "pending", @invitation.reload.status

    payload_json = discard_events.first.payload.to_json
    assert_not_includes payload_json, @raw_token
    assert_not_includes log.string, @sealed
    assert_includes log.string, "permanent_smtp_discard"
    assert_includes log.string, "invitation_id=#{@invitation.id}"
    assert_not_includes log.string, @raw_token
  end
end
