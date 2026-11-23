# frozen_string_literal: true

require "test_helper"

class PublicContent::ServiceSlugTest < ActiveSupport::TestCase
  test "parameterizes title" do
    org = organizations(:ant_marine)
    slug = PublicContent::ServiceSlug.generate(
      title: "Marine Warranty Survey",
      organization: org
    )
    assert_equal "marine-warranty-survey", slug
  end

  test "deduplicates colliding slugs" do
    org = organizations(:ant_marine)
    services(:marine_surveys_draft)
    slug = PublicContent::ServiceSlug.generate(
      title: "Marine surveys",
      organization: org
    )
    assert_match(/\Amarine-surveys(-\d+)?\z/, slug)
    refute_equal "marine-surveys", slug if Service.exists?(slug: "marine-surveys", organization: org)
  end

  test "handles non latin titles" do
    org = organizations(:ant_marine)
    slug = PublicContent::ServiceSlug.generate(title: "ひらがな", organization: org)
    assert_predicate slug, :present?
    assert_match(Service::SLUG_FORMAT, slug)
  end
end
