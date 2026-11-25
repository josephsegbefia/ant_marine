# frozen_string_literal: true

require "test_helper"

class Commercial::QuotePdfRendererTest < ActiveSupport::TestCase
  def pdf_text(data)
    data.b.scan(/\[(.*?)\]\s*TJ|<([0-9a-fA-F]+)>\s*Tj/m).map do |array, single|
      chunks = array ? array.scan(/<([0-9a-fA-F]+)>/).flatten : [ single ]
      chunks.map { |hex| [ hex ].pack("H*").force_encoding("Windows-1252").encode("UTF-8") }.join
    end.join("\n")
  end

  test "draft PDF is clearly marked and shows the full commercial content" do
    quote = create_ready_quote(lines: [ [ "Underwater hull inspection", "2", "1250.00" ], [ "Mobilisation", "1", "300.50" ] ])
    text = pdf_text(Commercial::QuotePdfRenderer.render(quote: quote))

    assert_includes text, "DRAFT — NOT A FINAL OFFER"
    assert_includes text, "DRAFT"
    assert_includes text, quote.reference_number
    assert_includes text, "Version 1"
    assert_includes text, "Harbour Logistics Ltd"
    assert_includes text, "Ama Mensah"
    assert_includes text, "Hull inspection for MV Example"
    assert_includes text, "Inspection report with photographs."
    assert_includes text, "Repairs and dry-docking."
    assert_includes text, "Underwater hull inspection"
    assert_includes text, "Mobilisation"
    assert_includes text, "GHS 1,250.00"
    assert_includes text, "GHS 2,500.00"
    assert_includes text, "GHS 300.50"
    assert_includes text, "GHS 2,800.50"
    assert_includes text, "Payable within 30 days of invoice."
    assert_includes text, (Date.current + 30).strftime("%-d %B %Y")
  end

  test "internal notes never appear on the PDF" do
    quote = create_ready_quote
    quote.current_revision.update!(internal_notes: "Margin is thin — staff only")
    text = pdf_text(Commercial::QuotePdfRenderer.render(quote: quote.reload))
    assert_not_includes text, "Margin is thin"
  end

  test "approved PDF uses the frozen recipient snapshot and truthful status" do
    quote = approve_quote!(create_ready_quote)
    Quote.where(id: quote.id).update_all(prospective_client: { "company_name" => "Changed Later Ltd", "contact_name" => "X" })
    text = pdf_text(Commercial::QuotePdfRenderer.render(quote: quote.reload))

    assert_includes text, "APPROVED VERSION — NOT YET SENT TO THE CLIENT"
    assert_includes text, "Harbour Logistics Ltd"
    assert_not_includes text, "Changed Later Ltd"
    assert_not_includes text, "NOT A FINAL OFFER"
  end

  test "PDF after correction and approval shows the approved content and stored units" do
    quote = create_ready_quote(lines: [ [ "Diving day", "2", "800.00" ], [ "Sediment removal", "3", "50.00" ] ])
    revision = quote.current_revision
    revision.line_items.first.update!(unit_choice: "day")
    revision.line_items.last.update!(unit_choice: "other", unit_other: "tonne")
    Commercial::QuoteTransition.apply!(quote: quote, action: :submit_for_review, membership: memberships(:dual_staff))
    review_quote!(quote, :return_for_correction, reason: "Change the title")
    revision.reload.update!(title: "Corrected hull inspection")
    approve_quote!(quote)

    text = pdf_text(Commercial::QuotePdfRenderer.render(quote: quote.reload))
    assert_includes text, "APPROVED VERSION — NOT YET SENT TO THE CLIENT"
    assert_includes text, "Corrected hull inspection"
    assert_not_includes text, "Hull inspection for MV Example"
    assert_includes text, "day"
    assert_includes text, "tonne"
    assert_includes text, "GHS 1,750.00"
  end

  test "withdrawn quotations are marked as no longer valid" do
    quote = approve_quote!(create_ready_quote)
    Commercial::QuoteTransition.apply!(quote: quote, action: :withdraw, membership: memberships(:dual_staff))
    assert_includes pdf_text(Commercial::QuotePdfRenderer.render(quote: quote.reload)), "WITHDRAWN"
  end

  test "long quotations render across multiple numbered pages" do
    lines = 45.times.map { |i| [ "Inspection item #{i + 1} with a reasonably long description of the work", "1", "100.00" ] }
    quote = create_ready_quote(lines: lines)
    data = Commercial::QuotePdfRenderer.render(quote: quote)
    text = pdf_text(data)

    assert_operator data.scan(%r{/Type /Page\b}).size, :>=, 2
    assert_includes text, "Inspection item 45"
    assert_includes text, "Page 1 of"
    assert_includes text, "GHS 4,500.00"
  end

  test "characters outside the PDF font are replaced instead of failing" do
    quote = create_ready_quote
    quote.current_revision.update!(title: "Inspection ₵ 漢字 ✓")
    assert_nothing_raised { Commercial::QuotePdfRenderer.render(quote: quote.reload) }
  end
end
