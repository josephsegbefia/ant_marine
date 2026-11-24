# frozen_string_literal: true

require "test_helper"

class Staff::QuotationsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
  end

  test "index requires permission and lists quotations" do
    quote = Commercial::QuoteBuilder.create!(organization: organizations(:ant_marine), membership: memberships(:dual_staff))
    get staff_quotations_path
    assert_response :success
    assert_select "h1", text: /Quotations/
    assert_includes response.body, quote.reference_number
  end

  test "staff without quotes permission is denied" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))
    get staff_quotations_path
    assert_redirected_to root_path
  end

  test "create quotation and save client step" do
    get new_staff_quotation_path
    assert_redirected_to %r{/staff/quotations/\d+/edit}
    quote = Quote.order(:id).last
    patch staff_quotation_path(quote), params: {
      editor_step: 1,
      quote: {
        lock_version: quote.lock_version,
        prospective_client: {
          company_name: "Harbour Shipping Ltd",
          contact_name: "Ama Mensah",
          email: "procurement@example.test"
        }
      },
      quote_revision: { title: "Vessel inspection quote" }
    }
    assert_redirected_to %r{editor_step=}
    quote.reload
    assert_equal "Harbour Shipping Ltd", quote.prospective_client["company_name"]
  end

  test "pdf requires authorization" do
    quote = Commercial::QuoteBuilder.create!(organization: organizations(:ant_marine), membership: memberships(:dual_staff))
    get pdf_staff_quotation_path(quote)
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end
end
