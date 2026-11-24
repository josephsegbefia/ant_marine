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

  test "GET new does not create a quotation record" do
    assert_no_difference -> { Quote.count } do
      get new_staff_quotation_path
    end
    assert_response :success
    assert_select "button", text: /Begin draft quotation/
  end

  test "POST create starts draft and redirects to editor" do
    assert_difference -> { Quote.count }, 1 do
      post staff_quotations_path
    end
    quote = Quote.order(:id).last
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 1)
    follow_redirect!
    assert_response :success
    assert_includes response.body, quote.reference_number
  end

  test "GET edit is authorized for coordinator" do
    quote = Commercial::QuoteBuilder.create!(organization: organizations(:ant_marine), membership: memberships(:dual_staff))
    get edit_staff_quotation_path(quote, editor_step: 1)
    assert_response :success
  end

  test "create quotation and save client step" do
    post staff_quotations_path
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

  test "refreshing GET new does not duplicate drafts" do
    2.times { get new_staff_quotation_path }
    assert_equal 0, Quote.count
  end

  test "frozen quotation rejects PATCH update" do
    quote = Commercial::QuoteBuilder.create!(organization: organizations(:ant_marine), membership: memberships(:dual_staff))
    Commercial::QuoteTransition.apply!(quote: quote, action: :submit_for_review, membership: memberships(:dual_staff))
    Commercial::QuoteTransition.apply!(quote: quote, action: :approve, membership: memberships(:dual_staff))

    patch staff_quotation_path(quote), params: {
      editor_step: 1,
      quote: { lock_version: quote.lock_version, prospective_client: { company_name: "Evil Co" } },
      quote_revision: { title: "Changed" }
    }
    assert_redirected_to root_path
    quote.reload
    assert_not_equal "Evil Co", quote.prospective_client["company_name"]
  end

  test "pdf requires authorization" do
    quote = Commercial::QuoteBuilder.create!(organization: organizations(:ant_marine), membership: memberships(:dual_staff))
    get pdf_staff_quotation_path(quote)
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "general staff cannot open editor" do
    quote = Commercial::QuoteBuilder.create!(organization: organizations(:ant_marine), membership: memberships(:dual_staff))
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))
    get edit_staff_quotation_path(quote)
    assert_response :not_found
  end
end
