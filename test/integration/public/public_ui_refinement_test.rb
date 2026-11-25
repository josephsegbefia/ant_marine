# frozen_string_literal: true

require "test_helper"

class Public::PublicUiRefinementTest < ActionDispatch::IntegrationTest
  test "homepage includes maritime hero art and service cards" do
    get root_path
    assert_response :success
    assert_select ".public-hero--home"
    assert_select ".public-hero-art__svg"
    assert_select ".public-service-card", minimum: 0
    assert_select "a.public-text-link", text: /Learn more/, minimum: 0
  end

  test "service listing uses service card component" do
    get public_services_path
    assert_response :success
    assert_select ".public-page-banner h1", text: /Practical help/
    assert_select ".public-section--sky .public-service-showcase"
    assert_select ".public-service-card--premium", minimum: 1
    assert_includes response.body, "public-service-card__pattern"
    assert_select ".public-notice--help"
  end

  test "service detail uses structured layout and contact cta" do
    get public_service_path("published-surveys")
    assert_response :success
    assert_select ".public-detail__layout"
    assert_select ".public-detail__article"
    assert_select "a[href=?]", contact_path, text: "Enquire about this service"
    assert_select "a[href=?]", contact_path, text: "Contact the team"
    assert_select ".public-breadcrumb a", text: "Services"
  end

  test "empty our work page uses the featured card empty state" do
    get public_projects_path
    assert_response :success
    assert_select ".public-service-showcase--solo .public-service-card--featured" do
      assert_select ".public-service-card__title", text: /not available yet/
      assert_select ".public-service-card__highlights li", count: 4
      assert_select "a[href=?]", contact_path, text: "Discuss a similar project"
    end
    assert_select ".public-card-carousel", count: 0
  end

  test "header exposes primary and secondary navigation" do
    get root_path
    assert_select "nav#public-primary-nav a", text: "Services"
    assert_select "details.public-header__more summary", text: "More"
    assert_select "details.public-header__more a", text: "Resources"
  end
end
