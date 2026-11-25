# frozen_string_literal: true

require "test_helper"

class Public::PagesTest < ActionDispatch::IntegrationTest
  test "static pages respond" do
    get about_path
    assert_response :success
    get industries_path
    assert_response :success
    get how_we_work_path
    assert_response :success
    get contact_path
    assert_response :success
  end

  test "published contact page content" do
    get contact_path
    assert_includes response.body, "Contact"
  end

  test "about page lists published services and the working journey" do
    get about_path
    assert_response :success

    assert_select ".public-about__service-list a[href=?]", public_service_path(services(:marine_surveys_published).slug)
    assert_select ".public-about__service-list", text: /#{services(:marine_surveys_draft).title}\z/, count: 0
    assert_select ".public-about__pillars li", count: 4
    assert_select "#about-process-heading"
  end

  test "industries page shows an icon card for each industry" do
    get industries_path

    assert_select ".public-industry-card", count: 6
    assert_select ".public-industry-card .public-service-card__icon svg", count: 6
    assert_no_match(/staff website tools/, response.body)
  end

  test "contact page shows channels without internal project wording" do
    get contact_path

    assert_select ".public-contact__item", count: 4
    assert_select ".public-contact__value", text: "To be confirmed", minimum: 1
    assert_select ".public-contact__side a[href=?]", new_session_path, text: "Sign in"
    assert_no_match(/F4-02/, response.body)
  end

  test "contact page links a published email address" do
    public_site_pages(:contact_published).update_columns(published_page_data: { "email" => "hello@example.test" })

    get contact_path

    assert_select ".public-contact__value a[href=?]", "mailto:hello@example.test"
  end

  test "how we work page shows process journey and expectations" do
    get how_we_work_path
    assert_response :success

    assert_select "#public-page-banner-heading", text: "How we work"
    assert_select "#how-process-heading", text: "Four straightforward steps"
    assert_select ".public-steps .public-steps__item", count: PublicContent::HomepagePresenter::PROCESS_STEPS.size
    assert_select "#how-assurance-heading", text: "Honest expectations"
    assert_select ".public-service-card", count: PublicContent::HowWeWorkPresenter::DEFAULT_ASSURANCE_CARDS.size
    assert_select "#public-cta-heading", text: "Ready to start the conversation?"
    assert_select ".public-page-banner a[href=?]", contact_path, text: "Get in touch"
  end
end
