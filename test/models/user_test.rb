require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email" do
    user = User.new(email: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email)
  end

  test "password change bumps security version and revokes sessions" do
    user = users(:staff_only)
    session = Session.issue_for!(user: user, ip_address: "127.0.0.1", user_agent: "test")
    version = user.security_version

    user.update!(password: "new-password-12", password_confirmation: "new-password-12")

    assert_operator user.reload.security_version, :>, version
    assert session.reload.revoked_at.present?
  end
end
