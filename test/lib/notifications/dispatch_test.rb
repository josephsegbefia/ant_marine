# frozen_string_literal: true

require "test_helper"

class NotificationsDispatchTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  test "catalogue only includes the access emails that exist today; enquiry notices are in-app only" do
    email_events = Notifications::Events::CATALOGUE.select { |_, event| event[:channel] == "email" }.keys.sort
    assert_equal %w[invitation.issued password.reset_requested], email_events
    in_app = Notifications::Events::CATALOGUE.reject { |key, _| email_events.include?(key) }
    assert_equal StaffNotification::KINDS.sort, in_app.keys.sort
    assert(in_app.values.all? { |event| event[:channel] == "in_app" })
  end

  test "test environment does not use a live queue or smtp" do
    assert_kind_of ActiveJob::QueueAdapters::TestAdapter, ActiveJob::Base.queue_adapter
    assert_equal :test, ActionMailer::Base.delivery_method
  end

  test "development and production configs select solid queue" do
    development = Rails.root.join("config/environments/development.rb").read
    production = Rails.root.join("config/environments/production.rb").read

    assert_match(/queue_adapter = :solid_queue/, development)
    assert_match(/queue_adapter = :solid_queue/, production)
    assert_match(/delivery_method = :file/, development)
    assert_match(/SMTP_ADDRESS/, production)

    guard = Rails.root.join("config/initializers/mail_delivery_guard.rb").read
    assert_match(/MailDelivery/, guard)
  end

  test "password reset still enqueues the mailer without a raw token argument" do
    user = users(:staff_only)

    assert_enqueued_email_with PasswordsMailer, :reset, args: [ user ] do
      Notifications::Dispatch.password_reset!(user: user)
    end
  end
end
