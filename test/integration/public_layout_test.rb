# frozen_string_literal: true

require "test_helper"

class PublicLayoutTest < ActionDispatch::IntegrationTest
  test "homepage renders without authentication" do
    get root_path
    assert_response :success
    assert_select "h1", text: /Marine expertise for projects that matter/
    assert_select "a.public-header__cta[href=?]", new_session_path, text: /Sign in/
    assert_no_match(/Oceanic Shipping/, response.body)
    assert_no_match(/GH₵/, response.body)
  end

  test "authenticated user visiting root is redirected to workspace" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    get root_path
    assert_redirected_to staff_root_path
  end
end
