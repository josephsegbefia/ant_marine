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
end
