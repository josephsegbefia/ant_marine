# frozen_string_literal: true

require "test_helper"

class Staff::ArticleCreateActionTextTest < ActionDispatch::IntegrationTest
  HTML = "<h2>Section</h2><p><strong>Bold</strong> text</p>"

  test "post create article saves action text body" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)

    assert_difference [ "Article.count", "ActionText::RichText.count" ], 1 do
      post staff_website_articles_path, params: {
        article: {
          title: "Testing",
          summary: "Lets test",
          body: HTML,
          category: "guidance",
          seo_title: "",
          seo_description: ""
        }
      }
    end

    article = Article.order(:id).last
    assert_redirected_to staff_website_article_path(article)
    assert_equal "draft", article.status
    assert_includes article.body.to_plain_text, "Bold"
    assert_equal 1, ActionText::RichText.where(record: article, name: "body").count

    get edit_staff_website_article_path(article)
    assert_response :success
    assert_includes response.body, "ant-rich-text-toolbar"
    assert_includes response.body, "Testing"
  end
end
