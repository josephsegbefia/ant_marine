# frozen_string_literal: true

require "test_helper"

class NotificationsMailDeliveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  test "test environment is always considered ready" do
    assert Notifications::MailDelivery.configured?
    assert_nothing_raised { Notifications::MailDelivery.ensure_ready! }
  end

  test "production without smtp is not configured" do
    with_production_env(smtp_address: nil) do
      assert_not Notifications::MailDelivery.configured?
      assert_equal "missing_smtp", Notifications::MailDelivery.readiness_label
    end
  end

  test "dispatch refuses invitation enqueue when production mail is not ready" do
    invitation = invitations(:pending_staff_invite)

    with_production_env(smtp_address: nil) do
      assert_raises(Notifications::MailDelivery::NotConfigured) do
        Notifications::Dispatch.invitation!(invitation: invitation, raw_token: FIXTURE_STAFF_TOKEN)
      end
    end

    assert_no_enqueued_jobs only: DeliverInvitationEmailJob
  end

  test "dispatch refuses password reset when production mail is not ready" do
    user = users(:staff_only)

    with_production_env(smtp_address: nil) do
      assert_raises(Notifications::MailDelivery::NotConfigured) do
        Notifications::Dispatch.password_reset!(user: user)
      end
    end

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob
  end

  private

    def with_production_env(smtp_address:)
      original_env = ENV["SMTP_ADDRESS"]
      original_delivery = ActionMailer::Base.delivery_method
      original_raise = ActionMailer::Base.raise_delivery_errors

      ENV["SMTP_ADDRESS"] = smtp_address
      Rails.env = ActiveSupport::StringInquirer.new("production")
      ActionMailer::Base.delivery_method = smtp_address.present? ? :smtp : :test
      ActionMailer::Base.raise_delivery_errors = true

      yield
    ensure
      ENV["SMTP_ADDRESS"] = original_env
      Rails.env = ActiveSupport::StringInquirer.new("test")
      ActionMailer::Base.delivery_method = original_delivery
      ActionMailer::Base.raise_delivery_errors = original_raise
    end
end
