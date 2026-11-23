# frozen_string_literal: true

require "test_helper"

class Public::PagesTest < ActionDispatch::IntegrationTest
  test "static pages respond" do
    get about_path
    assert_response :success
    get industries_path
    assert_response :success
    get how_we_work_path
    assert_response :success
    get contact_path
    assert_response :success
  end

  test "published contact page content" do
    get contact_path
    assert_includes response.body, "Contact"
  end
end
