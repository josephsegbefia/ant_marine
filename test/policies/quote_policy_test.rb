# frozen_string_literal: true

require "test_helper"

class QuotePolicyTest < ActiveSupport::TestCase
  setup do
    @quote = Commercial::QuoteBuilder.create!(
      organization: organizations(:ant_marine),
      membership: memberships(:dual_staff)
    )
  end

  test "coordinator can manage drafts" do
    policy = QuotePolicy.new(memberships(:dual_staff), @quote)
    assert policy.update?
    assert policy.submit_for_review?
  end

  test "general staff cannot view quotations" do
    policy = QuotePolicy.new(memberships(:staff_membership), @quote)
    assert_not policy.show?
    assert_not policy.create?
  end
end
