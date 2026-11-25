# frozen_string_literal: true

require "test_helper"

class QuoteAssociationsTest < ActiveSupport::TestCase
  setup do
    @quote = create_draft_quote
  end

  test "an active client organisation can be linked" do
    @quote.client_organization_id = organizations(:acme_client).id
    assert @quote.valid?, @quote.errors.full_messages.inspect
  end

  test "ANT Marine itself or a non-client organisation is rejected" do
    @quote.client_organization_id = organizations(:ant_marine).id
    assert_not @quote.valid?
    assert_includes @quote.errors[:client_organization_id], "Choose a client organisation from the list."
  end

  test "archived or inactive client organisations are rejected" do
    client = organizations(:other_client)
    client.update_columns(archived_at: Time.current)
    @quote.client_organization_id = client.id
    assert_not @quote.valid?
  end

  test "a forged organisation id is rejected" do
    @quote.client_organization_id = Organization.maximum(:id).to_i + 1000
    assert_not @quote.valid?
  end

  test "only published services of the quoting organisation can be linked" do
    published = Service.published_catalogue.where(organization: organizations(:ant_marine)).first
    if published
      @quote.service_id = published.id
      assert @quote.valid?, @quote.errors.full_messages.inspect
    end

    draft = Service.where.not(status: "published").first
    if draft
      @quote.service_id = draft.id
      assert_not @quote.valid?
    end

    @quote.service_id = Service.maximum(:id).to_i + 1000
    assert_not @quote.valid?
    assert_includes @quote.errors[:service_id], "Choose a published service from the list."
  end

  test "editable only in draft or returned for correction" do
    assert @quote.editable?
    %w[pending_review approved_for_issuance issued withdrawn superseded].each do |status|
      @quote.status = status
      assert_not @quote.editable?, "#{status} should not be editable"
    end
    @quote.status = "returned_for_correction"
    assert @quote.editable?
  end
end
