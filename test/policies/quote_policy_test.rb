# frozen_string_literal: true

require "test_helper"

class QuotePolicyTest < ActiveSupport::TestCase
  setup do
    @quote = create_ready_quote
    @coordinator = memberships(:dual_staff)
    @general = memberships(:staff_membership)
    @client = memberships(:client_membership)
  end

  test "coordinator can view and edit workspace" do
    policy = QuotePolicy.new(@coordinator, @quote)
    assert policy.show?
    assert policy.edit?
    assert policy.pdf?
    assert policy.update?
    assert policy.submit_for_review?
  end

  test "general staff and client users cannot access quotations" do
    [ @general, @client ].each do |membership|
      policy = QuotePolicy.new(membership, @quote)
      assert_not policy.show?
      assert_not policy.edit?
      assert_not policy.create?
      assert_not policy.update?
      assert_not policy.pdf?
      assert_not policy.approve?
    end
    assert_empty QuotePolicy::Scope.new(@client, Quote).resolve
  end

  test "pending review is read-only and only reviewers may decide" do
    Commercial::QuoteTransition.apply!(quote: @quote, action: :submit_for_review, membership: @coordinator)
    @quote.reload

    policy = QuotePolicy.new(@coordinator, @quote)
    assert_not policy.update?
    assert_not policy.submit_for_review?
    assert policy.approve?
    assert policy.return_for_correction?

    deny_permission!(@coordinator, "quotes.approve")
    restricted = QuotePolicy.new(Membership.find(@coordinator.id), @quote)
    assert_not restricted.approve?
    assert_not restricted.return_for_correction?
  end

  test "frozen approved revision allows view-only edit access not update" do
    approve_quote!(@quote)
    @quote.reload

    policy = QuotePolicy.new(@coordinator, @quote)
    assert policy.edit?, "review screen should remain reachable"
    assert_not policy.update?
    assert_not policy.approve?
    assert_not policy.issue?, "issuing stays gated until F4-02B"
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
