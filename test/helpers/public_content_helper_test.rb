# frozen_string_literal: true

require "test_helper"

class PublicContentHelperTest < ActionView::TestCase
  include PublicContentHelper

  test "strips script tags from formatted text" do
    html = public_format_text("<script>alert(1)</script><p>Safe</p>")
    assert_not_includes html, "script"
    assert_includes html, "Safe"
  end
end
