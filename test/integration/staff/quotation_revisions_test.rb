# frozen_string_literal: true

require "test_helper"

class Staff::QuotationRevisionsTest < ActionDispatch::IntegrationTest
  setup do
    @quote = approve_quote!(create_ready_quote)
    sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
  end

  test "approved quotation offers a new version and shows the version history" do
    get edit_staff_quotation_path(@quote, editor_step: 5)
    assert_response :success
    assert_select "#quote-create-revision button", text: "Create new version"
    assert_select "#quote-versions .staff-quote-versions__item", count: 1
    assert_select "#quote-versions", text: /Approved — not sent/
    assert_select "#quote-versions", text: /Not sent to the client/
  end

  test "creating a new version opens an editable draft and keeps version 1 viewable" do
    assert_difference -> { QuoteRevision.count } => 1 do
      post create_revision_staff_quotation_path(@quote), params: reviewer_form_params(@quote).merge(revision_reason: "Add a second dive day")
    end
    assert_redirected_to edit_staff_quotation_path(@quote, editor_step: 2)
    follow_redirect!
    assert_select "#quote-revision-context", text: /Version 2 revises/
    assert_select "#quote-revision-context", text: /Add a second dive day/
    assert_select "#quote-versions .staff-quote-versions__item", count: 2
    assert_select "#quote-versions", text: /Current working draft/

    get version_staff_quotation_path(@quote, version_number: 1)
    assert_response :success
    assert_select "h1", text: "Hull inspection for MV Example"
    assert_select "body", text: /exactly as it was approved/
    assert_select "a[href=?]", pdf_staff_quotation_path(@quote, version: 1)
    assert_select "#quote-readiness", count: 0
  end

  test "a new unsent version names the earlier sent version as the client's offer" do
    mark_issued!(@quote)
    create_revision!(@quote)

    get edit_staff_quotation_path(@quote, editor_step: 5)
    assert_response :success
    assert_select ".staff-quote-summary", text: /Version 1 was sent earlier and is still the client’s offer/
  end

  test "creating a version without a reason or with a stale page does nothing" do
    assert_no_difference -> { QuoteRevision.count } do
      post create_revision_staff_quotation_path(@quote), params: reviewer_form_params(@quote).merge(revision_reason: "")
    end
    assert_equal "Explain why a new version is needed.", flash[:alert]

    assert_no_difference -> { QuoteRevision.count } do
      post create_revision_staff_quotation_path(@quote), params: { expected_revision_id: 0, expected_lock_version: 0, revision_reason: "x" }
    end
    assert_equal Commercial::QuoteTransition::STALE_MESSAGE, flash[:alert]
  end

  test "historical PDF downloads are private and match the requested version" do
    create_revision!(@quote)
    @quote.reload.current_revision.update!(title: "Revised scope title")

    get pdf_staff_quotation_path(@quote, version: 1)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_match(/-v1\.pdf/, response.headers["Content-Disposition"])
    assert_includes extract_pdf_text(response.body), "Hull inspection for MV Example"
    assert_not_includes extract_pdf_text(response.body), "Revised scope title"

    get pdf_staff_quotation_path(@quote, version: 2)
    assert_match(/-v2-DRAFT\.pdf/, response.headers["Content-Disposition"])
    assert_includes extract_pdf_text(response.body), "Revised scope title"
  end

  test "people without quotation access cannot view versions or create them" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))

    get version_staff_quotation_path(@quote, version_number: 1)
    assert_response :not_found
    assert_no_difference -> { QuoteRevision.count } do
      post create_revision_staff_quotation_path(@quote), params: reviewer_form_params(@quote).merge(revision_reason: "x")
    end
    assert_response :not_found
  end

  test "viewer without prepare permission does not see the new version form and is refused" do
    deny_permission!(memberships(:dual_staff), "quotes.create")
    get edit_staff_quotation_path(@quote, editor_step: 5)
    assert_select "#quote-create-revision", count: 0

    assert_no_difference -> { QuoteRevision.count } do
      post create_revision_staff_quotation_path(@quote), params: reviewer_form_params(@quote).merge(revision_reason: "x")
    end
    assert_equal "You do not have permission to do that.", flash[:alert]
  end

  test "unknown version numbers return not found" do
    get version_staff_quotation_path(@quote, version_number: 9)
    assert_response :not_found
  end
end
