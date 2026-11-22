require "test_helper"

class PasswordResetFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  test "password reset journey with generic messaging" do
    user = users(:staff_only)

    post passwords_path, params: { email: user.email }
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select ".login-notice", text: /if user with that email address exists/

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      post passwords_path, params: { email: "unknown-#{SecureRandom.hex(4)}@example.com" }
    end
    follow_redirect!
    assert_select ".login-notice", text: /if user with that email address exists/
  end

  test "edit reset page uses branded access shell" do
    user = users(:staff_only)

    get edit_password_path(user.password_reset_token)
    assert_response :success
    assert_select ".login-page"
    assert_select "h2", text: "Choose a new password."
    assert_select "button[type=submit]", text: /Save password/
  end

  test "invalid reset token redirects to forgot password with alert" do
    get edit_password_path("not-a-valid-token")
    assert_redirected_to new_password_path
    follow_redirect!
    assert_select ".login-alert", text: /invalid or has expired/
  end

  test "mismatched passwords render branded validation state" do
    user = users(:staff_only)
    token = user.password_reset_token

    put password_path(token), params: { password: "new-password-12", password_confirmation: "different" }
    assert_response :unprocessable_entity
    assert_select ".login-page"
    assert_select ".login-alert"
  end

  test "successful reset allows sign in with new password" do
    user = users(:client_only)
    token = user.password_reset_token

    put password_path(token), params: { password: "new-password-12", password_confirmation: "new-password-12" }
    assert_redirected_to new_session_path

    post session_path, params: { email: user.email, password: "new-password-12" }
    assert_redirected_to client_root_path
  ensure
    user.update!(password: "password")
  end
end
