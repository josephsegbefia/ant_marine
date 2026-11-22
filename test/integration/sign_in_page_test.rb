require "test_helper"

class SignInPageTest < ActionDispatch::IntegrationTest
  test "sign in page matches design studio structure and loads tailwind" do
    get new_session_path

    assert_response :success
    assert_select 'link[rel="stylesheet"][href*="tailwind"]', minimum: 1
    assert_select ".login-page"
    assert_select ".login-panel h1", text: /Every marine project deserves a clearer journey/
    assert_select "h2", text: "Welcome back."
    assert_select "label", text: "Work email"
    assert_select "label", text: "Password"
    assert_select "input[name=email]"
    assert_select "input[name=password]"
    assert_select "button[type=submit]", text: /Sign in/
    assert_select "a[href=?]", new_password_path, text: "Forgot password?"
    assert_select ".login-form__invite", text: /invitation/
  end

  test "sign in page shows alert without revealing account existence copy from design" do
    get new_session_path
    assert_response :success

    post session_path, params: { email: "nobody@example.com", password: "wrong" }
    follow_redirect!

    assert_select "[data-toast-stack-flash-value]"
    assert_match(/Try another email address or password/i, response.body)
  end
end
