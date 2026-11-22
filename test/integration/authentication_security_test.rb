require "test_helper"

class AuthenticationSecurityTest < ActionDispatch::IntegrationTest
  test "unknown user login fails" do
    post session_path, params: { email: "nobody@example.com", password: "password" }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "logged-out route denial" do
    get staff_root_path
    assert_redirected_to new_session_path
  end

  test "revoked session denial" do
    user = users(:staff_only)
    sign_in_as(user, membership: memberships(:staff_membership))
    Current.session.revoke!

    get staff_root_path
    assert_redirected_to new_session_path
  end

  test "security version invalidation" do
    user = users(:staff_only)
    sign_in_as(user, membership: memberships(:staff_membership))
    user.increment!(:security_version)

    get staff_root_path
    assert_redirected_to new_session_path
  end

  test "public health check remains accessible" do
    get rails_health_check_path
    assert_response :success
  end

  test "session context does not bleed after sign out" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))
    delete session_path

    get staff_root_path
    assert_redirected_to new_session_path
  end
end
