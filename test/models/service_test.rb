# frozen_string_literal: true

require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  test "generates slug from title on create" do
    org = organizations(:ant_marine)
    service = Service.new(organization: org, title: "Marine Warranty Survey", category: "marine_surveys")
    assert service.valid?
    assert_equal "marine-warranty-survey", service.slug
  end

  test "coerces malformed list input to empty arrays" do
    org = organizations(:ant_marine)
    service = Service.new(organization: org, title: "List test", category: "marine_surveys", scope_items: "oops")
    service.valid?
    assert_equal [], service.scope_items
  end

  test "empty scope and process arrays are valid" do
    org = organizations(:ant_marine)
    service = Service.new(
      organization: org,
      title: "Harbour checks",
      category: "marine_surveys",
      scope_items: [],
      process_steps: []
    )
    assert service.valid?, service.errors.full_messages.to_sentence
  end

  test "does not change slug when title changes" do
    service = services(:marine_surveys_draft)
    original = service.slug
    service.update!(title: "Renamed service")
    assert_equal original, service.reload.slug
  end

  test "forged slug in attributes is ignored on update" do
    service = services(:marine_surveys_draft)
    original = service.slug
    service.assign_attributes(slug: "hacked-slug", title: service.title)
    service.save!
    assert_equal original, service.reload.slug
  end

  test "published snapshot unchanged after draft edit" do
    service = services(:marine_surveys_published)
    prior_body = service.published_body
    service.body = "<p>New draft only body text</p>"
    service.save!
    assert_equal prior_body, service.reload.published_body
  end

  test "editorial validation required before review" do
    service = services(:marine_surveys_draft)
    service.summary = nil
    assert_not service.valid?(:editorial)
  end

  test "publish transition copies snapshot" do
    service = services(:marine_surveys_draft)
    membership = memberships(:super_admin_membership)
    PublicContent::Transition.submit_for_review!(record: service, membership: membership)
    PublicContent::Transition.approve!(record: service.reload, membership: membership)
    PublicContent::Transition.publish!(record: service.reload, membership: membership)

    service.reload
    assert_equal "published", service.status
    assert_equal service.title, service.published_title
  end
end
