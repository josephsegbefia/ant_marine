# frozen_string_literal: true

require "test_helper"

class QuotePolicyTest < ActiveSupport::TestCase
  setup do
    @quote = Commercial::QuoteBuilder.create!(
      organization: organizations(:ant_marine),
      membership: memberships(:dual_staff)
    )
    @coordinator = memberships(:dual_staff)
    @general = memberships(:staff_membership)
  end

  test "coordinator can view and edit workspace" do
    policy = QuotePolicy.new(@coordinator, @quote)
    assert policy.show?
    assert policy.edit?
    assert policy.pdf?
    assert policy.update?
    assert policy.submit_for_review?
  end

  test "general staff cannot access quotations" do
    policy = QuotePolicy.new(@general, @quote)
    assert_not policy.show?
    assert_not policy.edit?
    assert_not policy.create?
    assert_not policy.update?
  end

  test "frozen approved revision allows view-only edit access not update" do
    Commercial::QuoteTransition.apply!(quote: @quote, action: :submit_for_review, membership: @coordinator)
    Commercial::QuoteTransition.apply!(quote: @quote, action: :approve, membership: @coordinator)
    @quote.reload

    policy = QuotePolicy.new(@coordinator, @quote)
    assert policy.edit?, "review screen should remain reachable"
    assert_not policy.update?
    assert_not @quote.editable?
  end

  test "policy exposes all standard quotation actions" do
    policy = QuotePolicy.new(@coordinator, @quote)
    %i[index? show? new? create? edit? update? pdf?
       submit_for_review? return_for_correction? approve? issue? withdraw?].each do |method|
      assert policy.respond_to?(method), "missing #{method}"
    end
  end
end
