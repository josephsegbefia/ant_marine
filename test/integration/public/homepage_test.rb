# frozen_string_literal: true

require "test_helper"

class Public::HomepageTest < ActionDispatch::IntegrationTest
  test "renders the P01 sections in order" do
    get root_path
    assert_response :success

    assert_select ".public-hero--home h1", text: /Marine expertise for projects that matter/
    assert_select ".public-hero-art svg.public-hero-art__svg"
    assert_select ".public-trust-bar__list li", count: 4
    assert_select "#home-services-heading", text: "How we can help"
    assert_select "#home-process-heading"
    assert_select ".public-steps .public-steps__item", count: PublicContent::HomepagePresenter::PROCESS_STEPS.size
    assert_select "#public-cta-heading", text: "Tell us what you need."
  end

  test "closing call to action points to contact and offers workspace sign in" do
    get root_path

    assert_select ".public-cta a[href=?]", contact_path, text: "Get in touch"
    assert_select ".public-cta a[href=?]", new_session_path
    assert_no_match(/Online quote and booking forms are not available yet/, response.body)
  end

  test "shows published services only" do
    get root_path

    assert_select ".public-service-card__title", text: services(:marine_surveys_published).public_title
    assert_select ".public-service-card__title", text: services(:marine_surveys_draft).title, count: 0
    assert_select "#services.public-section--sky"
    assert_select ".public-service-showcase--solo .public-service-card--featured"
    assert_select ".public-service-card__highlights li", minimum: 1
  end

  test "several published services scroll as full cards with arrows and automatic play controls" do
    hull = publish_extra_service("hull-cleaning", "Hull cleaning")

    get root_path

    assert_select ".public-service-showcase--solo", count: 0
    assert_select ".public-card-carousel[data-controller=card-carousel][aria-roledescription=carousel]" do
      assert_select ".public-card-carousel__slide[aria-roledescription=slide]", count: 2
      assert_select ".public-card-carousel__slide .public-service-card--featured", count: 2
      assert_select ".public-card-carousel__slide a[href=?]", public_service_path(hull.slug), text: "Explore this service"
      assert_select "button[aria-label='Previous service']"
      assert_select "button[aria-label='Next service']"
      assert_select "button[aria-label='Pause automatic scrolling']"
      assert_select ".public-card-carousel__dot", count: 2
    end
    assert_select ".public-service-card__title", text: services(:marine_surveys_draft).title, count: 0
  end

  test "hides the project section when no case study is published" do
    organizations(:ant_marine).case_studies.create!(
      slug: "draft-story", title: "Draft vessel story", summary: "Not cleared", status: "draft"
    )

    get root_path

    assert_select "#home-work-heading", count: 0
    assert_no_match(/Draft vessel story/, response.body)
  end

  test "lists published case studies with a link to the story" do
    study = organizations(:ant_marine).case_studies.create!(
      slug: "cleared-story", title: "Cleared story", summary: "Internal summary", status: "published",
      published_title: "Hull condition review", published_summary: "Shared with permission.",
      published_industry: "Shipowners", published_at: 1.day.ago
    )

    get root_path

    assert_select "#home-work-heading", text: "Explore our work"
    assert_select ".public-project-card a[href=?]", public_project_path(study.slug), text: "Hull condition review"
    assert_select ".public-project-card .public-eyebrow", text: "Shipowners"
  end

  test "shows published insights only" do
    get root_path

    assert_select "#home-insights-heading", text: "Latest insights"
    assert_select ".public-service-card__title a[href=?]", public_insight_path(articles(:insight_published).slug)
    assert_no_match(/#{articles(:insight_draft).title}/, response.body)
  end

  test "hides insights when none are published" do
    Article.update_all(status: "draft")

    get root_path

    assert_select "#home-insights-heading", count: 0
  end

  test "industries fall back to approved default cards" do
    get root_path

    assert_select "#home-industries-heading", text: "Industries we serve"
    assert_select ".public-industries__item", count: 6
    assert_select ".public-industries a[href=?]", industries_path
  end

  test "layout provides skip link and full footer navigation" do
    get root_path

    assert_select "a.public-skip-link[href='#main-content']"
    assert_select "main#main-content"
    assert_select ".public-footer nav[aria-label=Company] a[href=?]", about_path
    assert_select ".public-footer nav[aria-label=Company] a[href=?]", how_we_work_path
    assert_select ".public-footer a[href=?]", contact_path
  end

  test "services page shows every published service in the carousel" do
    publish_extra_service("hull-cleaning", "Hull cleaning")
    publish_extra_service("draft-survey", "Draft survey")

    get public_services_path

    assert_select ".public-card-carousel .public-card-carousel__slide", count: 3
    assert_select ".public-card-carousel .public-service-card__footer a[href=?]", contact_path, minimum: 3
  end

  private
    def publish_extra_service(slug, title)
      organizations(:ant_marine).services.create!(
        slug: slug, title: title, summary: "Internal", category: "marine_surveys", status: "published",
        published_title: title, published_summary: "#{title} for vessels and marine facilities.",
        published_scope_items: [ "Inspection" ], published_process_steps: [], published_display_order: 5,
        published_at: 1.hour.ago
      )
    end
end
