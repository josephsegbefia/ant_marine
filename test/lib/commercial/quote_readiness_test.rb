# frozen_string_literal: true

require "test_helper"

class Commercial::QuoteReadinessTest < ActiveSupport::TestCase
  test "a new empty draft lists every missing commercial detail" do
    quote = create_draft_quote
    messages = Commercial::QuoteReadiness.check(quote).map(&:message)

    assert_includes messages, "Choose a client organisation or enter the company name."
    assert_includes messages, "Add the name of the person receiving this quotation."
    assert_includes messages, "Add the recipient's email address."
    assert_includes messages, "Give the quotation a clear title describing the work."
    assert_includes messages, "Describe the scope of work."
    assert_includes messages, "List what the client will receive."
    assert(messages.any? { |m| m.start_with?("State what is not included") })
    assert_includes messages, "Add at least one pricing line."
    assert_includes messages, "Set the date this quotation is valid until."
    assert_includes messages, "Add the payment terms agreed for this quotation."
  end

  test "a complete quotation is ready" do
    quote = create_ready_quote
    assert Commercial::QuoteReadiness.new(quote).ready?, Commercial::QuoteReadiness.check(quote).map(&:message).inspect
  end

  test "invalid email, past validity, zero total and undescribed lines block readiness" do
    quote = create_ready_quote(lines: [ [ "", "1", "0" ] ])
    quote.update!(prospective_client: quote.prospective_client.merge("email" => "not-an-email"))
    quote.current_revision.update!(valid_until: Date.current - 1)
    messages = Commercial::QuoteReadiness.check(quote.reload).map(&:message)

    assert_includes messages, "Check the recipient's email address."
    assert_includes messages, "The validity date has passed. Choose a future date."
    assert_includes messages, "Pricing line 1: add a description."
    assert_includes messages, "The quotation total must be greater than zero."
  end

  test "stale stored totals are detected" do
    quote = create_ready_quote
    quote.current_revision.update_columns(total_cents: 1)
    messages = Commercial::QuoteReadiness.check(quote.reload).map(&:message)
    assert_includes messages, "The quotation total is out of date. Save the pricing again."
  end

  test "each issue points to the editor step that fixes it" do
    steps = Commercial::QuoteReadiness.check(create_draft_quote).map(&:step).uniq.sort
    assert_equal [ 1, 2, 3, 4 ], steps
  end
end
