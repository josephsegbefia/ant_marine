# frozen_string_literal: true

require "test_helper"

class ActionTextPersistenceTest < ActiveSupport::TestCase
  HTML = "<h2>Section</h2><p><strong>Bold</strong> and <em>italic</em>.</p><ul><li>One</li></ul>"

  PERSISTABLES = [
    [ Article, :articles, { title: "Insight", summary: "Intro", category: "guidance" } ],
    [ TrainingOffering, :training_offerings, { title: "Course", summary: "Intro", audience: "Officers" } ],
    [ PublicResource, :public_resources, { title: "Guide", summary: "Intro" } ],
    [ Service, :services, { title: "Service", summary: "Intro", category: "marine_surveys", audience: "Owners" } ],
    [ PublicSitePage, :public_site_pages, { title: "Page", summary: "Intro", page_key: "industries" } ]
  ].freeze

  test "migrated models do not expose legacy body column" do
    PERSISTABLES.each do |klass, _assoc, _extra|
      assert_not_includes klass.column_names, "body", "#{klass.name} must not have legacy body column"
    end
    assert_not_includes CaseStudy.column_names, "body"
    assert_not_includes CaseStudy.column_names, "client_challenge"
  end

  test "each editorial model saves rich text without legacy column insert" do
    org = organizations(:ant_marine)

    PERSISTABLES.each do |klass, assoc, extra|
      record = org.public_send(assoc).build(extra.merge(status: "draft"))
      record.body = HTML
      assert record.save!, "#{klass.name} should save with rich text body"
      rich = ActionText::RichText.find_by(record: record, name: "body")
      assert rich.present?, "#{klass.name} should have ActionText body"
      assert_includes rich.body.to_s, "Bold"
      record.reload
      assert_includes record.body.to_plain_text, "Bold"
    end
  end

  test "case study structured rich text fields persist" do
    org = organizations(:ant_marine)
    study = org.case_studies.build(title: "Story", summary: "Intro", service_category: "marine_surveys")
    study.body = HTML
    study.client_challenge = "<p>Challenge</p>"
    study.approach = "<p>Approach</p>"
    assert study.save!

    %i[body client_challenge approach].each do |attr|
      assert ActionText::RichText.exists?(record: study, name: attr.to_s)
    end
  end

  test "article mass assignment through build hash persists rich text only" do
    org = organizations(:ant_marine)
    article = org.articles.build(
      title: "Testing",
      summary: "Lets test",
      category: "guidance",
      body: HTML
    )
    assert_difference -> { ActionText::RichText.count }, 1 do
      assert article.save!
    end
    assert_equal "draft", article.status
    assert_not_includes Article.column_names, "body"
  end
end
