# frozen_string_literal: true

require "test_helper"

# Capybara 3.40 resets Chrome with Storage.clearDataForOrigin(origin: "*"), which Chrome 158+
# rejects. Clear cookies through a supported CDP command instead.
module ChromeResetCompatibility
  def execute_cdp(cmd, **args)
    return super unless cmd == "Storage.clearDataForOrigin" && args[:origin] == "*"

    super("Network.clearBrowserCookies")
  end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeResetCompatibility)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AntSelectSystemHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  setup do
    Rails.application.config.x.session_rate_limit_store&.clear
  end

  # Always isolate browser state between identities.
  # Fixture users use password: "password".
  # create_staff_membership!(..., password:) overrides the default Secure-password-123.
  def sign_in_through_form(user, password: "Secure-password-123")
    Capybara.reset_sessions!
    Rails.application.config.x.session_rate_limit_store&.clear

    visit new_session_path
    assert_current_path new_session_path

    fill_in "Work email", with: user.email
    fill_in "Password", with: password
    click_on "Sign in"
    assert_no_current_path new_session_path, wait: 10
  rescue Minitest::Assertion
    flunk "Sign-in failed for #{user.email}: #{page.text.to_s.truncate(240)}"
  end
end
