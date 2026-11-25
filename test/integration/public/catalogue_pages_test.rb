# frozen_string_literal: true

require "test_helper"

class Public::CataloguePagesTest < ActionDispatch::IntegrationTest
  setup do
    @org = organizations(:ant_marine)
  end

  test "training scrolls published courses as full cards with learning outcomes" do
    publish_training("inspection-basics", "Inspection basics", published_learning_objectives: [ "Prepare a clear scope" ])
    publish_training("report-writing", "Report writing")
    @org.training_offerings.create!(slug: "draft-course", title: "Draft course", summary: "x", status: "draft")

    get public_training_path

    assert_select ".public-card-carousel[data-card-carousel-noun-value=Course]" do
      assert_select ".public-card-carousel__slide .public-service-card--featured", count: 2
      assert_select ".public-service-card__highlights li", text: /Prepare a clear scope/
      assert_select "button[aria-label='Next course']"
    end
    assert_no_match(/Draft course/, response.body)
  end

  test "training without courses shows the featured empty state" do
    get public_training_path

    assert_select ".public-service-showcase--solo .public-service-card__title", text: /No published training offerings yet/
    assert_select ".public-card-carousel", count: 0
  end

  test "training details show course information and topics" do
    training = publish_training("inspection-basics", "Inspection basics",
      published_audience: "Vessel operators", published_delivery_format: "workshop",
      published_learning_objectives: [ "Prepare a clear scope" ], published_topics: [ "Records" ])

    get public_training_offering_path(training.slug)

    assert_select ".public-breadcrumb a[href=?]", public_training_path
    assert_select ".public-check-list li", text: /Prepare a clear scope/
    assert_select ".public-topic-list li", text: "Records"
    assert_select ".public-detail-facts__row dd", text: "Vessel operators"
    assert_select ".public-detail-facts__row dd", text: "Workshop"
    assert_select ".public-detail-aside a[href=?]", contact_path, text: "Ask about training"
  end

  test "insights list published articles in the carousel and hide drafts" do
    @org.articles.create!(slug: "second-insight", title: "Second insight", summary: "x", status: "published",
      published_title: "Second insight", published_summary: "Second summary", published_at: 1.hour.ago)

    get public_insights_path

    assert_select ".public-card-carousel .public-card-carousel__slide", count: 2
    assert_select ".public-card-carousel a[href=?]", public_insight_path("published-insight"), text: "Read article"
    assert_select ".public-featured-meta", text: /Published/
    assert_no_match(/Draft insight article/, response.body)
  end

  test "article page links to other published insights only" do
    @org.articles.create!(slug: "second-insight", title: "Second insight", summary: "x", status: "published",
      published_title: "Second insight", published_summary: "Second summary", published_at: 1.hour.ago)

    get public_insight_path("published-insight")

    assert_select ".public-detail__prose", text: /Public body/
    assert_select ".public-detail-links a[href=?]", public_insight_path("second-insight")
    assert_select ".public-detail-links a[href=?]", public_insight_path("published-insight"), count: 0
    assert_select ".public-detail-links a[href=?]", public_insight_path("draft-insight"), count: 0
  end

  test "resources use the library list with honest availability" do
    publish_resource("survey-guide", "Survey guide", published_resource_category: "guide", published_file_release_enabled: true)
    publish_resource("company-profile", "Company profile")

    get public_resources_path

    assert_select ".public-library__item", count: 2
    assert_select ".public-library__item", text: /Survey guide/ do
      assert_select ".public-library__badge--ready", text: /Download coming soon/
    end
    assert_select ".public-library__badge", text: /Information only/
    assert_select ".public-library__count", text: "2 resources"
  end

  test "resources without entries show the featured empty state" do
    get public_resources_path

    assert_select ".public-service-card__title", text: /No public resources available yet/
    assert_select ".public-library", count: 0
  end

  test "resource details describe type and availability" do
    resource = publish_resource("survey-guide", "Survey guide", published_resource_category: "guide",
      published_related_content_label: "Marine surveys")

    get public_resource_path(resource.slug)

    assert_select ".public-detail-facts__row dd", text: "Technical guide"
    assert_select ".public-detail-facts__row dd", text: "Marine surveys"
    assert_select ".public-detail-facts__row dd", text: /Information only/
  end

  test "project story shows only published story sections" do
    story = @org.case_studies.create!(slug: "hull-review", title: "Hull review", summary: "x", status: "published",
      published_title: "Hull review", published_summary: "Shared with permission.",
      published_client_challenge: "<p>Operator needed a condition view.</p>",
      published_outcome: "<p>Owner planned the next steps.</p>",
      published_service_category: "marine_surveys", published_at: 1.hour.ago,
      approach: "<p>Unreviewed draft approach</p>")

    get public_project_path(story.slug)

    assert_select ".public-detail__heading", text: "The challenge"
    assert_select ".public-detail__heading", text: "The outcome"
    assert_select ".public-detail__heading", text: "Our approach", count: 0
    assert_no_match(/Unreviewed draft approach/, response.body)
    assert_select ".public-detail-facts__row dd", text: "Marine surveys"
    assert_select ".public-detail-aside a[href=?]", contact_path, text: "Discuss a similar project"
  end

  private
    def publish_training(slug, title, **attributes)
      @org.training_offerings.create!(slug: slug, title: title, summary: "x", status: "published",
        published_title: title, published_summary: "#{title} for marine teams.", published_at: 1.hour.ago, **attributes)
    end

    def publish_resource(slug, title, **attributes)
      @org.public_resources.create!(slug: slug, title: title, summary: "x", status: "published",
        published_title: title, published_summary: "#{title} overview.", published_at: 1.hour.ago, **attributes)
    end
end
