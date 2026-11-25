# frozen_string_literal: true

require "test_helper"

class QuoteImmutabilityTest < ActiveSupport::TestCase
  setup do
    @quote = approve_quote!(create_ready_quote)
    @revision = QuoteRevision.find(@quote.current_revision_id)
    @item = @revision.line_items.first
  end

  test "approved revision fields cannot change after a fresh load" do
    %i[title scope_description deliverables exclusions payment_terms valid_until currency].each do |field|
      revision = QuoteRevision.find(@revision.id)
      value = field == :valid_until ? Date.current + 90 : (field == :currency ? "USD" : "Tampered")
      revision.public_send("#{field}=", value)
      assert_not revision.save, "#{field} changed on a frozen revision"
      assert_includes revision.errors[:base], QuoteRevision::FROZEN_MESSAGE
    end
    assert_equal "Hull inspection for MV Example", @revision.reload.title
  end

  test "approved revision totals and recipient snapshot cannot be rewritten" do
    revision = QuoteRevision.find(@revision.id)
    revision.total_cents = 1
    revision.recipient_snapshot = { "company_name" => "Someone else" }
    assert_not revision.save
  end

  test "approved line items cannot be edited, added or deleted" do
    item = QuoteLineItem.find(@item.id)
    item.unit_price = "1.00"
    assert_not item.save
    assert_includes item.errors[:base], QuoteRevision::FROZEN_MESSAGE

    assert_not QuoteLineItem.new(quote_revision_id: @revision.id, description: "Extra", quantity: 1, unit: "each").save

    assert_not QuoteLineItem.find(@item.id).destroy
    assert QuoteLineItem.exists?(@item.id)
  end

  test "nested line item tampering through the revision is rejected" do
    revision = QuoteRevision.find(@revision.id)
    revision.assign_attributes(line_items_attributes: { "0" => { id: @item.id, unit_price: "1.00" } })
    assert_not revision.save

    revision = QuoteRevision.find(@revision.id)
    revision.assign_attributes(line_items_attributes: { "0" => { id: @item.id, _destroy: "1" } })
    assert_not revision.save
    assert QuoteLineItem.exists?(@item.id)

    revision = QuoteRevision.find(@revision.id)
    revision.assign_attributes(line_items_attributes: { "0" => { description: "Sneaky", quantity: "1", unit_price: "5" } })
    assert_not revision.save
    assert_equal 1, @revision.line_items.count
  end

  test "approved revision cannot be destroyed" do
    assert_not QuoteRevision.find(@revision.id).destroy
  end

  test "recipient and service cannot change once out of draft" do
    quote = Quote.find(@quote.id)
    quote.prospective_client = quote.prospective_client.merge("company_name" => "Other Co")
    assert_not quote.save
    assert_match(/cannot be changed/, quote.errors[:base].first)
  end

  test "the approve-to-issue metadata change remains permitted" do
    revision = QuoteRevision.find(@revision.id)
    assert revision.update(revision_status: "issued", issued_at: Time.current, issued_by_membership: memberships(:dual_staff))
  end

  test "frozen revision status cannot move backwards" do
    revision = QuoteRevision.find(@revision.id)
    revision.revision_status = "draft"
    assert_not revision.save
  end

  test "authorship and approver of an approved revision cannot be rewritten" do
    revision = QuoteRevision.find(@revision.id)
    assert_equal memberships(:ops_manager_membership).id, revision.approved_by_membership_id
    assert_equal memberships(:dual_staff).id, revision.prepared_by_membership_id

    revision.contributor_membership_ids = []
    revision.prepared_by_membership_id = nil
    assert_not revision.save

    revision = QuoteRevision.find(@revision.id)
    revision.approved_by_membership = memberships(:super_admin_membership)
    assert_not revision.save
    assert_equal memberships(:ops_manager_membership).id, @revision.reload.approved_by_membership_id
  end

  test "approved units cannot be switched through the unit picker" do
    item = QuoteLineItem.find(@item.id)
    item.unit_choice = "day"
    assert_not item.save
    assert_equal "each", @item.reload.unit
  end

  test "database rejects approved revisions without a freeze timestamp" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Quote.transaction(requires_new: true) do
        QuoteRevision.where(id: @revision.id).update_all(frozen_at: nil)
      end
    end
    assert_not_nil @revision.reload.frozen_at
  end
end
