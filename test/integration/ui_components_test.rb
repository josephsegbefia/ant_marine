# frozen_string_literal: true

require "test_helper"

class UiComponentsTest < ActionDispatch::IntegrationTest
  test "staff invitations include custom select markup and toast stack" do
    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))

    get staff_invitations_path
    assert_response :success

    assert_select "[data-controller='toast-stack']"
    assert_select "[data-controller='custom-select']"
    assert_select "select[name='role_key'].ant-select__native"
    assert_select "button.ant-select__trigger[aria-haspopup='listbox']"
    assert_select "[data-controller='form-submit']"
    assert_match(/General Staff/, response.body)
    assert_no_match(/provisional/i, response.body)
  end

  test "sign in page uses unified fields without inline flash banners" do
    get new_session_path
    assert_response :success

    assert_select "[data-controller='toast-stack']"
    assert_select ".ant-field"
    assert_select "input.ant-control[name='email']"
    assert_select ".login-alert", count: 0
    assert_select ".login-notice", count: 0
  end

  test "failed sign in exposes toast payload in layout" do
    post session_path, params: { email: "nobody@example.com", password: "wrong" }
    assert_redirected_to new_session_path

    follow_redirect!
    assert_select "[data-toast-stack-flash-value*='error']"
    assert_match(/Try another email address or password/i, response.body)
  end

  test "password reset flash maps to toast data" do
    post passwords_path, params: { email: users(:super_admin).email }
    assert_redirected_to new_session_path

    follow_redirect!
    assert_select "[data-toast-stack-flash-value*='success']"
    assert_match(/if user with that email address exists/i, response.body)
  end
end
