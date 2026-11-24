# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteTransitionTest < ActiveSupport::TestCase
  setup do
    @membership = memberships(:dual_staff)
    @quote = Commercial::QuoteBuilder.create!(organization: organizations(:ant_marine), membership: @membership)
  end

  test "submit_for_review moves draft to pending_review" do
    Commercial::QuoteTransition.apply!(quote: @quote, action: :submit_for_review, membership: @membership)
    assert_equal "pending_review", @quote.reload.status
  end

  test "approve requires permission and freezes revision" do
    Commercial::QuoteTransition.apply!(quote: @quote, action: :submit_for_review, membership: @membership)
    Commercial::QuoteTransition.apply!(quote: @quote, action: :approve, membership: @membership)
    @quote.reload
    assert_equal "approved_for_issuance", @quote.status
    assert @quote.current_revision.frozen?
  end

  test "general staff cannot approve" do
    Commercial::QuoteTransition.apply!(quote: @quote, action: :submit_for_review, membership: @membership)
    staff = memberships(:staff_membership)
    assert_raises(Commercial::QuoteTransition::InvalidTransition) do
      Commercial::QuoteTransition.apply!(quote: @quote, action: :approve, membership: staff)
    end
  end
end
