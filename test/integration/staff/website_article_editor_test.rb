# frozen_string_literal: true

require "test_helper"

class Staff::WebsiteArticleEditorTest < ActionDispatch::IntegrationTest
  setup do
    @membership = memberships(:super_admin_membership)
    sign_in_as users(:super_admin), membership: @membership
    @article = articles(:insight_draft)
  end

  test "new insight shows guided editorial workspace" do
    get new_staff_website_article_path
    assert_response :success
    assert_select ".staff-editor-stepper [role='tab']", 3
    assert_includes response.body, "Create an insight"
    assert_includes response.body, "Save and continue"
    assert_includes response.body, "staff-editorial-wizard"
    refute_match(/>\s*save_continue\s*</i, response.body)
  end

  test "edit opens requested step" do
    get edit_staff_website_article_path(@article, step: 2)
    assert_response :success
    assert_match(/id="editor-step-panel-2"[^>]*>/, response.body)
    assert_match(/hidden[^>]*id="editor-step-panel-1"|id="editor-step-panel-1"[^>]*hidden/, response.body)
  end

  test "save and continue advances step" do
    patch staff_website_article_path(@article), params: {
      article: {
        title: @article.title,
        summary: @article.summary,
        body: "<p>Updated body</p>",
        category: @article.category
      },
      commit: "save_continue",
      editor_step: 1
    }

    assert_redirected_to edit_staff_website_article_path(@article, step: 2)
  end

  test "review step shows workflow actions when draft" do
    get edit_staff_website_article_path(@article, step: 3)
    assert_response :success
    assert_includes response.body, "Submit for review"
  end
end
