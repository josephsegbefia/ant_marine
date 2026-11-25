# frozen_string_literal: true

require "test_helper"

class Public::OurWorkPageTest < ActionDispatch::IntegrationTest
  test "a single published story uses the featured card without carousel controls" do
    story = publish_story("hull-condition-review", "Hull condition review",
      published_industry: "Shipowners", published_service_category: "marine_surveys")

    get public_projects_path

    assert_select ".public-card-carousel", count: 0
    assert_select ".public-service-showcase--solo .public-service-card--featured" do
      assert_select ".public-eyebrow", text: "Shipowners"
      assert_select ".public-project-facts dd", text: "Marine surveys"
      assert_select "a[href=?]", public_project_path(story.slug), text: "Read the story"
    end
  end

  test "several published stories scroll in a carousel with arrows and play controls" do
    publish_story("hull-condition-review", "Hull condition review")
    publish_story("mooring-assessment", "Mooring assessment",
      published_outcome: "<p>The operator <strong>resumed</strong> berthing on schedule.</p>")

    get public_projects_path

    assert_select ".public-card-carousel[data-controller=card-carousel][data-card-carousel-noun-value='Project story']" do
      assert_select ".public-card-carousel__slide .public-service-card--featured", count: 2
      assert_select "button[aria-label='Previous project story']"
      assert_select "button[aria-label='Next project story']"
      assert_select "button[aria-label='Pause automatic scrolling']"
      assert_select ".public-project-facts dd", text: "The operator resumed berthing on schedule."
    end
  end

  test "draft stories and unapproved draft fields never appear" do
    organizations(:ant_marine).case_studies.create!(
      slug: "draft-story", title: "Draft vessel story", summary: "Not cleared", status: "draft"
    )
    publish_story("cleared-story", "Cleared story", industry: "Unreviewed draft industry")

    get public_projects_path

    assert_no_match(/Draft vessel story/, response.body)
    assert_no_match(/Unreviewed draft industry/, response.body)
    assert_select ".public-service-card--featured .public-eyebrow", text: "Project story"
  end

  private
    def publish_story(slug, title, **attributes)
      organizations(:ant_marine).case_studies.create!(
        slug: slug, title: title, summary: "Internal", status: "published",
        published_title: title, published_summary: "#{title} shared with client permission.",
        published_at: 1.hour.ago, **attributes
      )
    end
end
