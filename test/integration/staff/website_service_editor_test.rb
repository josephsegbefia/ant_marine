# frozen_string_literal: true

require "test_helper"

class Staff::WebsiteServiceEditorTest < ActionDispatch::IntegrationTest
  setup do
    @membership = memberships(:super_admin_membership)
    sign_in_as users(:super_admin), membership: @membership
    @service = services(:marine_surveys_draft)
  end

  test "edit shows four guided steps" do
    get edit_staff_website_service_path(@service)
    assert_response :success
    assert_select "[role='tab']", 4
    assert_select "#editor-step-panel-1"
    assert_select "#editor-step-panel-4"
  end

  test "edit opens requested step" do
    get edit_staff_website_service_path(@service, step: 3)
    assert_response :success
    assert_match(/id="editor-step-panel-3"[^>]*>/, response.body)
    assert_match(/hidden[^>]*id="editor-step-panel-1"|id="editor-step-panel-1"[^>]*hidden/, response.body)
  end

  test "update preserves scope items array params" do
    patch staff_website_service_path(@service), params: {
      service: {
        title: @service.title,
        slug: @service.slug,
        summary: @service.summary,
        category: @service.category,
        scope_items: [ "Updated item", "Second item" ],
        process_steps: [ "Step one" ]
      },
      commit: "save_continue",
      editor_step: 3
    }

    assert_redirected_to edit_staff_website_service_path(@service, step: 4)
    @service.reload
    assert_equal [ "Updated item", "Second item" ], @service.scope_items
    assert_equal [ "Step one" ], @service.process_steps
  end

  test "draft preview route remains staff only" do
    sign_out
    get edit_staff_website_service_path(@service)
    assert_redirected_to new_session_path
  end
end
