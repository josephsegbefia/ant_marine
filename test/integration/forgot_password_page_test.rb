require "test_helper"

class ForgotPasswordPageTest < ActionDispatch::IntegrationTest
  test "forgot password page matches access design system" do
    get new_password_path

    assert_response :success
    assert_select 'link[rel="stylesheet"][href*="tailwind"]', minimum: 1
    assert_select ".login-page"
    assert_select "h2", text: "Reset your password."
    assert_select "label", text: "Work email"
    assert_select "input[name=email]"
    assert_select "button[type=submit]", text: /Send reset link/
    assert_select "a.ant-back-link[href=?]", new_session_path, text: /Back to sign in/
  end
end
