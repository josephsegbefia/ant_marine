# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteRevisionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    next unless @quote_id

    revision_ids = QuoteRevision.where(quote_id: @quote_id).pluck(:id)
    AuditEvent.where(subject_type: "Quote", subject_id: @quote_id).delete_all
    Quote.where(id: @quote_id).update_all(current_revision_id: nil)
    QuoteLineItem.where(quote_revision_id: revision_ids).delete_all
    QuoteRevision.where(id: revision_ids).update_all(superseded_by_revision_id: nil)
    QuoteRevision.where(id: revision_ids).order(version_number: :desc).each(&:delete)
    Quote.where(id: @quote_id).delete_all
  end

  test "two people creating a new version at the same moment produce exactly one" do
    quote = approve_quote!(create_ready_quote)
    @quote_id = quote.id
    expected = expected_version_for(quote)
    gate = Concurrent::CountDownLatch.new(1)

    outcomes = [ memberships(:dual_staff), memberships(:ops_manager_membership) ].map do |membership|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.wait
          Commercial::QuoteRevisionCreator.create!(quote: Quote.find(@quote_id), membership: membership,
                                                   reason: "Concurrent change", expected_version: expected)
          :created
        rescue Commercial::QuoteTransition::InvalidTransition
          :refused
        end
      end
    end
    gate.count_down

    assert_equal %i[created refused], outcomes.map(&:value).sort
    assert_equal [ 1, 2 ], QuoteRevision.where(quote_id: @quote_id).order(:version_number).pluck(:version_number)
  end
end
