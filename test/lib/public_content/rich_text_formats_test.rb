# frozen_string_literal: true

require "test_helper"

class PublicContent::RichTextFormatsTest < ActiveSupport::TestCase
  HTML = <<~HTML.strip
    <h2>Section</h2>
    <p><strong>Bold</strong> <em>italic</em> <u>underline</u> <del>strike</del></p>
    <blockquote>Quote</blockquote>
    <ul><li>One</li></ul>
    <ol><li>First</li></ol>
    <pre>code block</pre>
    <p><a href="https://example.com">Link</a></p>
  HTML

  test "sanitizer keeps supported formats and strips scripts" do
    dirty = "#{HTML}<script>alert(1)</script>"
    clean = PublicContent::RichText.sanitize_html(dirty)
    assert_includes clean, "<h2>"
    assert_includes clean, "<u>"
    assert_includes clean, "<del>"
    assert_includes clean, "<pre>"
    assert_not_includes clean, "script"
  end

  test "article save and reopen preserves formatted snapshot fields" do
    article = articles(:insight_draft)
    article.body = HTML
    assert article.save!

    snapshot = PublicContent::RichText.snapshot_html(article.body)
    assert_includes snapshot, "<u>"
    assert_includes snapshot, "<del>"
    assert_includes snapshot, "<pre>"

    article.reload
    assert_includes article.body.body.to_s, "underline"
  end

  test "draft rich text edit does not alter published snapshot" do
    published = articles(:insight_published)
    prior = published.published_body
    published.body = "<p><u>Draft only</u></p>"
    published.save!
    assert_equal prior, published.reload.published_body
  end
end
