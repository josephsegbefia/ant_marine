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
    assert_includes response.body, "staff-editor-preview"
    assert_not_includes response.body, "rails/active_storage/direct_uploads"
  end
end
