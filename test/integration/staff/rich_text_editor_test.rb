# frozen_string_literal: true

require "test_helper"

class Staff::RichTextEditorTest < ActionDispatch::IntegrationTest
  test "article edit renders trix editor without direct upload route" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    article = articles(:insight_draft)

    get edit_staff_website_article_path(article)
    assert_response :success
    assert_includes response.body, "trix-editor"
    assert_includes response.body, "ant-rich-text-toolbar"
    assert_includes response.body, "data-trix-attribute=\"underline\""
    assert_includes response.body, "More formatting"
    assert_includes response.body, "staff-editor-preview"
    assert_not_includes response.body, "rails/active_storage/direct_uploads"
  end

  test "rich text editors never use native required so hidden steps cannot block saving" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)

    [ new_staff_website_service_path, edit_staff_website_article_path(articles(:insight_draft)) ].each do |path|
      get path
      assert_response :success
      assert_select "trix-editor[required]", count: 0
      assert_select "trix-editor[aria-required=true]", minimum: 1
    end
  end
end
