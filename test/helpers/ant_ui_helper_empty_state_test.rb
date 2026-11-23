# frozen_string_literal: true

require "test_helper"

class AntUiHelperEmptyStateTest < ActionView::TestCase
  include AntUiHelper
  include Rails.application.routes.url_helpers

  test "renders context copy and icon" do
    html = ant_empty_state(
      icon: :layers,
      title: "No service pages yet",
      description: "Create a draft when ready.",
      primary_action: { label: "Create", path: "/staff/website/services/new" }
    )

    assert_includes html, "ant-empty-state"
    assert_includes html, "No service pages yet"
    assert_includes html, "Create a draft when ready."
    assert_includes html, "Create"
    assert_includes html, 'role="status"'
    assert_includes html, "ant-empty-state__title"
  end

  test "omits action row when no actions provided" do
    html = ant_empty_state(title: "Nothing here", description: "Check back later.")

    assert_not_includes html, "ant-empty-state__actions"
    assert_not_includes html, "ant-btn-primary"
  end

  test "supports variants and sizes" do
    html = ant_empty_state(
      title: "Muted",
      variant: :muted,
      size: :compact,
      tone: :info,
      guidance: "Helpful note"
    )

    assert_includes html, "ant-empty-state--muted"
    assert_includes html, "ant-empty-state--compact"
    assert_includes html, "ant-empty-state--info"
    assert_includes html, "Helpful note"
  end

  test "rejects external action paths" do
    assert_raises(ArgumentError) do
      ant_empty_state(
        title: "Bad",
        primary_action: { label: "Go", path: "https://example.com" }
      )
    end
  end
end
