# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteReferenceTest < ActiveSupport::TestCase
  test "references are sequential and human readable" do
    first = create_draft_quote
    second = create_draft_quote
    year = Time.current.year
    assert_match(/\AANT-Q-#{year}-\d{5}\z/, first.reference_number)
    assert_equal first.reference_number.split("-").last.to_i + 1, second.reference_number.split("-").last.to_i
  end

  test "allocation outside a transaction is refused" do
    connection = Quote.connection
    connection.define_singleton_method(:transaction_open?) { false }
    assert_raises(Commercial::QuoteReference::Collision) do
      Commercial::QuoteReference.generate!(organization: organizations(:ant_marine))
    end
  ensure
    connection.singleton_class.send(:remove_method, :transaction_open?)
  end

  test "malformed historic references do not break the next number" do
    quote = create_draft_quote
    quote.update_columns(reference_number: "ANT-Q-#{Time.current.year}-LEGACY")
    assert_match(/\AANT-Q-\d{4}-\d{5}\z/, create_draft_quote.reference_number)
  end
end

class Commercial::QuoteReferenceConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "concurrent drafts never receive the same reference" do
    organization = organizations(:ant_marine)
    membership = memberships(:dual_staff)
    created_ids = Concurrent::Array.new
    errors = Concurrent::Array.new
    gate = Concurrent::CountDownLatch.new(1)

    threads = 4.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.wait
          created_ids << Commercial::QuoteBuilder.create!(organization: organization, membership: membership).id
        rescue StandardError => e
          errors << e
        end
      end
    end
    gate.count_down
    threads.each(&:join)

    assert_empty errors.map(&:message)
    references = Quote.where(id: created_ids).pluck(:reference_number)
    assert_equal 4, references.size
    assert_equal references.uniq.size, references.size, "duplicate references: #{references.inspect}"
  ensure
    if created_ids&.any?
      AuditEvent.where(subject_type: "Quote", subject_id: created_ids).delete_all
      Quote.where(id: created_ids).update_all(current_revision_id: nil)
      QuoteRevision.where(quote_id: created_ids).delete_all
      Quote.where(id: created_ids).delete_all
    end
  end
end
