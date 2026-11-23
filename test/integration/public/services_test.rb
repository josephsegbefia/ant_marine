# frozen_string_literal: true

require "test_helper"

class Public::ServicesTest < ActionDispatch::IntegrationTest
  test "published service visible" do
    get public_service_path("published-surveys")
    assert_response :success
    assert_includes response.body, "Published surveys"
  end

  test "draft service not found" do
    get public_service_path("marine-surveys")
    assert_response :not_found
  end

  test "unknown slug returns not found" do
    get public_service_path("does-not-exist")
    assert_response :not_found
  end

  test "services index lists published only" do
    get public_services_path
    assert_response :success
    assert_includes response.body, "Published surveys"
    assert_not_includes response.body, "Draft body"
  end
end
