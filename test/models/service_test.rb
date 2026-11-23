# frozen_string_literal: true

require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  test "invalid slug rejected" do
    service = services(:marine_surveys_draft)
    service.slug = "Bad Slug"
    assert_not service.valid?
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
