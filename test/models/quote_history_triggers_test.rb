# frozen_string_literal: true

require "test_helper"

class QuoteHistoryTriggersTest < ActiveSupport::TestCase
  setup do
    @quote = approve_quote!(create_ready_quote)
    @revision = QuoteRevision.find(@quote.current_revision_id)
    @item = @revision.line_items.first
  end

  test "direct SQL cannot change frozen commercial content" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteRevision.connection.execute("UPDATE quote_revisions SET title = 'Tampered' WHERE id = #{@revision.id}")
      end
    end
    assert_equal "Hull inspection for MV Example", @revision.reload.title
  end

  test "direct SQL cannot clear frozen_at" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteRevision.connection.execute("UPDATE quote_revisions SET frozen_at = NULL WHERE id = #{@revision.id}")
      end
    end
    assert_not_nil @revision.reload.frozen_at
  end

  test "direct SQL cannot change pricing or recipient snapshot" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteRevision.connection.execute("UPDATE quote_revisions SET total_cents = 1 WHERE id = #{@revision.id}")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteRevision.connection.execute(
          "UPDATE quote_revisions SET recipient_snapshot = '{\"company_name\":\"Other\"}'::jsonb WHERE id = #{@revision.id}"
        )
      end
    end
  end

  test "direct SQL cannot insert update or delete frozen line items" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteLineItem.connection.execute(
          "INSERT INTO quote_line_items (quote_revision_id, description, quantity, unit, unit_price_cents, line_total_cents, position, created_at, updated_at)
           VALUES (#{@revision.id}, 'Extra', 1, 'each', 100, 100, 9, NOW(), NOW())"
        )
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteLineItem.connection.execute("UPDATE quote_line_items SET unit_price_cents = 1 WHERE id = #{@item.id}")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteLineItem.connection.execute("DELETE FROM quote_line_items WHERE id = #{@item.id}")
      end
    end
  end

  test "direct SQL cannot move a line item onto a frozen revision" do
    draft = create_ready_quote
    draft_item = draft.current_revision.line_items.first

    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteLineItem.connection.execute(
          "UPDATE quote_line_items SET quote_revision_id = #{@revision.id} WHERE id = #{draft_item.id}"
        )
      end
    end
  end

  test "legitimate issuance metadata remains permitted" do
    revision = QuoteRevision.find(@revision.id)
    assert revision.update(revision_status: "issued", issued_at: Time.current, issued_by_membership: memberships(:dual_staff))
  end

  test "history_bypass GUC cannot disable protection" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteRevision.connection.execute("SELECT set_config('ant_marine.history_bypass', 'on', true)")
        QuoteRevision.connection.execute("UPDATE quote_revisions SET title = 'Bypass attempt' WHERE id = #{@revision.id}")
      end
    end
    assert_equal "Hull inspection for MV Example", @revision.reload.title
  end

  test "TRUNCATE is revoked from PUBLIC on protected history tables" do
    # Table owners retain TRUNCATE; production gate requires a non-owner runtime role
    # (see scripts/verify_history_protection_h1.sh). This asserts PUBLIC no longer has it.
    %w[quote_revisions quote_line_items quote_responses].each do |table|
      granted = QuoteRevision.connection.select_value(<<~SQL.squish)
        SELECT COUNT(*) FROM information_schema.role_table_grants
        WHERE table_schema = 'public'
          AND table_name = #{QuoteRevision.connection.quote(table)}
          AND grantee = 'PUBLIC'
          AND privilege_type = 'TRUNCATE'
      SQL
      assert_equal 0, granted.to_i, "#{table} must not grant TRUNCATE to PUBLIC"
    end
  end

  test "completed quote responses are append-only" do
    release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: memberships(:ops_manager_membership),
      quote: @quote,
      quote_revision: @revision,
      client_organization: organizations(:acme_client)
    ).release
    response = Commercial::QuoteDecision.call(
      membership: memberships(:client_owner_membership),
      release: release,
      response: "accepted",
      confirmation: true,
      idempotency_key: "trigger-accept-1"
    ).response

    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteResponse.connection.execute("UPDATE quote_responses SET response = 'declined' WHERE id = #{response.id}")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteResponse.connection.execute("DELETE FROM quote_responses WHERE id = #{response.id}")
      end
    end
    assert_equal "accepted", response.reload.response
  end

  test "approval cannot race a concurrent line-item change" do
    quote = create_ready_quote
    Commercial::QuoteTransition.apply!(quote: quote, action: :submit_for_review, membership: memberships(:dual_staff))
    revision = quote.current_revision
    item = revision.line_items.first
    gate = Concurrent::CountDownLatch.new(1)
    outcomes = []

    editor = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        gate.wait
        Quote.transaction do
          QuoteRevision.lock.find(revision.id)
          item.update!(unit_price: "50.00")
          outcomes << :edited
        end
      end
    end

    approver = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        gate.wait
        begin
          Commercial::QuoteTransition.apply!(
            quote: Quote.find(quote.id),
            action: :approve,
            membership: memberships(:ops_manager_membership),
            expected_version: expected_version_for(quote)
          )
          outcomes << :approved
        rescue Commercial::QuoteTransition::StaleVersion, Commercial::QuoteTransition::InvalidTransition, ActiveRecord::StaleObjectError
          outcomes << :refused
        end
      end
    end

    gate.count_down
    [ editor, approver ].each(&:join)

    quote.reload
    if quote.status == "approved_for_issuance"
      assert quote.current_revision.version_frozen?
      assert_raises(ActiveRecord::StatementInvalid) do
        Quote.transaction(requires_new: true) do
          QuoteLineItem.connection.execute("UPDATE quote_line_items SET unit_price_cents = 1 WHERE id = #{item.id}")
        end
      end
    else
      assert_includes outcomes, :edited
      assert_includes %i[refused approved], outcomes.find { |o| o != :edited }
    end
  end
end
