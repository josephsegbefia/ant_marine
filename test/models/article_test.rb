# frozen_string_literal: true

require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "generates slug on create" do
    org = organizations(:ant_marine)
    article = Article.new(organization: org, title: "Harbour readiness guide")
    assert article.valid?
    assert_equal "harbour-readiness-guide", article.slug
  end

  test "publish snapshot copies content" do
    article = articles(:insight_draft)
    membership = memberships(:super_admin_membership)
    PublicContent::Transition.submit_for_review!(record: article, membership: membership)
    PublicContent::Transition.approve!(record: article.reload, membership: membership)
    PublicContent::Transition.publish!(record: article.reload, membership: membership)
    article.reload
    assert_equal "published", article.status
    assert_equal article.title, article.published_title
  end
end
