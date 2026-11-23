# frozen_string_literal: true

require "test_helper"

class HasPublicRichTextTest < ActiveSupport::TestCase
  test "snapshot and publish path strip attachment markup" do
    html = '<p>Hello</p><action-text-attachment sgid="fake"></action-text-attachment>'
    rich = ActionText::RichText.new(body: html)
    snapshot = PublicContent::RichText.snapshot_html(rich)
    assert_includes snapshot, "Hello"
    assert_not_includes snapshot, "action-text-attachment"
  end

  test "published snapshot unchanged when draft rich text changes" do
    service = services(:marine_surveys_published)
    prior = service.published_body
    service.body = "<p>Totally new draft copy with extra formatting.</p>"
    service.save!
    assert_equal prior, service.reload.published_body
  end
end
