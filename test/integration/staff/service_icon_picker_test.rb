# frozen_string_literal: true

require "test_helper"

class Staff::ServiceIconPickerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    @service = services(:marine_surveys_draft)
  end

  test "service editor shows visual icon picker on basics step" do
    get edit_staff_website_service_path(@service, step: 1)
    assert_response :success
    assert_select ".ant-icon-picker"
    assert_includes response.body, "Card icon"
    assert_includes response.body, "Survey"
    assert_includes response.body, "inspection"
    refute_includes response.body, 'id="service_icon_key_listbox"'
  end

  test "update preserves icon_key" do
    patch staff_website_service_path(@service), params: {
      service: {
        title: @service.title,
        summary: @service.summary,
        body: "<p>Body</p>",
        category: @service.category,
        audience: @service.audience,
        icon_key: "compass"
      },
      commit: "save_draft",
      editor_step: 1
    }
    assert_redirected_to edit_staff_website_service_path(@service, step: 1)
    assert_equal "compass", @service.reload.icon_key
  end
end
