# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteDecisionTest < ActiveSupport::TestCase
  setup do
    @actor = memberships(:ops_manager_membership)
    @client_org = organizations(:acme_client)
    @owner = memberships(:client_owner_membership)
    @member = memberships(:client_membership)
    @quote = approve_quote!(create_ready_quote)
    @quote.update_columns(client_organization_id: @client_org.id)
    @release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @actor,
      quote: @quote,
      quote_revision: @quote.current_revision,
      client_organization: @client_org
    ).release
  end

  test "authorized owner can record a simulated acceptance" do
    result = Commercial::QuoteDecision.call(
      membership: @owner,
      release: @release,
      response: "accepted",
      confirmation: true,
      idempotency_key: "accept-1"
    )

    assert result.created
    assert result.response.accepted?
    assert result.response.simulated?
    assert_equal @quote.current_revision_id, result.response.quote_revision_id
    assert AuditEvent.exists?(event_type: "quote.decision.accepted", subject_type: "Quote", subject_id: @quote.id)
    assert StaffNotification.exists?(kind: "quote_accepted", subject_type: "Quote", subject_id: @quote.id)
  end

  test "client member without accept permission is denied" do
    assert_raises(Commercial::QuoteDecision::Denied) do
      Commercial::QuoteDecision.call(
        membership: @member,
        release: @release,
        response: "accepted",
        confirmation: true
      )
    end
  end

  test "decline requires a reason and blocks a later accept" do
    Commercial::QuoteDecision.call(
      membership: @owner,
      release: @release,
      response: "declined",
      reason: "Budget postponed",
      confirmation: true,
      idempotency_key: "decline-1"
    )

    assert_raises(Commercial::QuoteDecision::Conflict) do
      Commercial::QuoteDecision.call(
        membership: @owner,
        release: @release,
        response: "accepted",
        confirmation: true,
        idempotency_key: "accept-after-decline"
      )
    end
  end

  test "request changes keeps the offer open for a later terminal decision" do
    Commercial::QuoteDecision.call(
      membership: @owner,
      release: @release,
      response: "changes_requested",
      reason: "Please add mobilisation as a separate line.",
      confirmation: true,
      idempotency_key: "changes-1"
    )

    result = Commercial::QuoteDecision.call(
      membership: @owner,
      release: @release,
      response: "accepted",
      confirmation: true,
      idempotency_key: "accept-after-changes"
    )
    assert result.response.accepted?
  end

  test "idempotent retries return the same decision" do
    first = Commercial::QuoteDecision.call(
      membership: @owner,
      release: @release,
      response: "accepted",
      confirmation: true,
      idempotency_key: "same-key"
    )
    second = Commercial::QuoteDecision.call(
      membership: @owner,
      release: @release,
      response: "accepted",
      confirmation: true,
      idempotency_key: "same-key"
    )

    assert first.created
    assert_not second.created
    assert_equal first.response.id, second.response.id
  end

  test "production refuses decisions" do
    original = Rails.env
    Rails.env = "production"
    assert_raises(Commercial::QuoteDecision::Denied) do
      Commercial::QuoteDecision.call(
        membership: @owner,
        release: @release,
        response: "accepted",
        confirmation: true
      )
    end
  ensure
    Rails.env = original
  end

  test "completed decisions are append-only at the database" do
    response = Commercial::QuoteDecision.call(
      membership: @owner,
      release: @release,
      response: "accepted",
      confirmation: true,
      idempotency_key: "append-only"
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
  end
end
