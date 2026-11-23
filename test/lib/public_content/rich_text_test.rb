# frozen_string_literal: true

require "test_helper"

class PublicContent::RichTextTest < ActiveSupport::TestCase
  test "sanitizes scripts and javascript links" do
    html = '<p>Hello</p><script>alert(1)</script><a href="javascript:evil">x</a>'
    result = PublicContent::RichText.sanitize_html(html)
    assert_includes result, "Hello"
    assert_not_includes result, "script"
    assert_not_includes result, "javascript:"
  end

  test "strips action text attachments" do
    html = '<p>Safe</p><action-text-attachment sgid="abc"></action-text-attachment>'
    assert PublicContent::RichText.attachments_present?(html)
    result = PublicContent::RichText.strip_attachments(html)
    assert_not_includes result, "action-text-attachment"
  end

  test "snapshot_html preserves formatting" do
    article = articles(:insight_draft)
    article.body = "<h2>Heading</h2><p>Paragraph <strong>bold</strong></p>"
    article.save!

    snapshot = PublicContent::RichText.snapshot_html(article.body)
    assert_includes snapshot, "<h2>"
    assert_includes snapshot, "<strong>"
  end
end
