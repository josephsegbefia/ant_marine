# frozen_string_literal: true

require "test_helper"

class ReadinessCheckTest < ActionDispatch::IntegrationTest
  test "GET /ready reports readiness without leaking secrets" do
    get readiness_check_path

    assert_response :success
    body = response.parsed_body
    assert_equal "ready", body["status"]
    assert body["checks"].any? { |c| c["name"] == "permission_catalogue" && c["ok"] }

    refute_includes response.body, "password"
    refute_includes response.body, "secret"
  end
end
