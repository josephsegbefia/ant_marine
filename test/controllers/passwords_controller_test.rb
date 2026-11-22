require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:staff_only) }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create" do
    post passwords_path, params: { email: @user.email }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path
  end

  test "create for unknown user" do
    post passwords_path, params: { email: "missing-user@example.com" }
    assert_no_enqueued_emails
    assert_redirected_to new_session_path
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "update" do
    token = @user.password_reset_token
    put password_path(token), params: { password: "new-password-12", password_confirmation: "new-password-12" }

    assert_redirected_to new_session_path
    assert @user.reload.authenticate("new-password-12")
  end
end
