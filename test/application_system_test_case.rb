# frozen_string_literal: true

require "test_helper"

# Capybara 3.40 resets Chrome with Storage.clearDataForOrigin(origin: "*"), which Chrome 158+
# rejects. Clear cookies and storage through supported commands instead.
module ChromeResetCompatibility
  def execute_cdp(cmd, **args)
    return super unless cmd == "Storage.clearDataForOrigin" && args[:origin] == "*"

    super("Network.clearBrowserCookies")
  end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeResetCompatibility)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  def sign_in_through_form(user, password: "Secure-password-123")
    visit new_session_path
    fill_in "Work email", with: user.email
    fill_in "Password", with: password
    click_on "Sign in"
    assert_no_current_path new_session_path
  end
end
