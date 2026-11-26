# frozen_string_literal: true

require "test_helper"

class Staff::QuotationIssuancesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @quote = approve_quote!(create_ready_quote)
    ActionMailer::Base.deliveries.clear
    sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
  end

  test "approved quotation links to the issuance preparation screen" do
    get edit_staff_quotation_path(@quote, editor_step: 5)
    assert_select "#quote-issuance-link a[href=?]", staff_quotation_issuance_path(@quote), text: "Prepare to send"
    assert_select "#quote-issuance-link", text: /Approved — not sent/
  end

  test "preparation screen shows the exact approved version, recipient, total, validity, PDF and method" do
    get staff_quotation_issuance_path(@quote)
    assert_response :success
    assert_select "h1", text: "Send quotation to client"
    assert_select "#issuance-mode", text: /Test delivery only/
    assert_select "dd", text: /Version 1/
    assert_select "dd", text: "ama@example.com"
    assert_select "dd", text: "Harbour Logistics Ltd"
    assert_select "dd", text: "GHS 2,500.00"
    assert_select "a[href=?]", pdf_staff_quotation_path(@quote, version: 1)
    assert_select "#issuance-prepare input[name=confirm_checked]"
  end

  test "prepare then send records truthful statuses" do
    post staff_quotation_issuance_path(@quote), params: reviewer_form_params(@quote).merge(confirm_checked: "1")
    assert_redirected_to staff_quotation_issuance_path(@quote)
    assert_equal "Prepared for sending. Nothing has been sent yet.", flash[:notice]
    delivery = @quote.quote_deliveries.last
    assert_equal "prepared", delivery.status

    post deliver_staff_quotation_issuance_path(@quote), params: { delivery_id: delivery.id }
    assert_equal "queued", delivery.reload.status
    perform_enqueued_jobs only: DeliverQuoteJob

    get staff_quotation_issuance_path(@quote)
    assert_select "#delivery-#{delivery.id}", text: /Accepted by the test mail system — no real email was sent/
    assert_select "body", text: /does not confirm the client received/
    assert_select "body", text: /Delivery confirmed/, count: 0
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "preparing without confirming the checks does nothing" do
    assert_no_difference -> { QuoteDelivery.count } do
      post staff_quotation_issuance_path(@quote), params: reviewer_form_params(@quote)
    end
    assert_equal "Confirm that you have checked the recipient and the PDF.", flash[:alert]
  end

  test "drafts cannot be opened for issuance and staff without send permission are refused" do
    draft = create_draft_quote
    get staff_quotation_issuance_path(draft)
    assert_redirected_to root_path

    deny_permission!(memberships(:dual_staff), "quotes.send")
    get staff_quotation_issuance_path(@quote)
    assert_redirected_to root_path
    assert_no_difference -> { QuoteDelivery.count } do
      post staff_quotation_issuance_path(@quote), params: reviewer_form_params(@quote).merge(confirm_checked: "1")
    end
    assert_redirected_to root_path
  end

  test "general staff cannot reach another team's quotation issuance" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))
    get staff_quotation_issuance_path(@quote)
    assert_response :not_found
  end

  test "stale page cannot prepare a delivery" do
    assert_no_difference -> { QuoteDelivery.count } do
      post staff_quotation_issuance_path(@quote), params: { expected_revision_id: @quote.current_revision_id,
                                                           expected_lock_version: @quote.lock_version + 5, confirm_checked: "1" }
    end
    assert_equal Commercial::QuoteTransition::STALE_MESSAGE, flash[:alert]
  end

  test "expired version shows the blocker instead of the prepare form" do
    quote = create_ready_quote
    quote.current_revision.update!(valid_until: Date.current + 1)
    approve_quote!(quote)
    travel_to(Date.current + 2.days) do
      sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
      get staff_quotation_issuance_path(quote)
      assert_select "#issuance-blockers", text: /expired/
      assert_select "#issuance-prepare", count: 0
    end
  end
end
