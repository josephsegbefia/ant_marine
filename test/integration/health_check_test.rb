require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "GET /up returns success when the application boots" do
    get rails_health_check_path

    assert_response :success
  end
end
