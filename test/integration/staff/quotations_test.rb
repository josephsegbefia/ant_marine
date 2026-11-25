# frozen_string_literal: true

require "test_helper"

class Staff::QuotationsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
  end

  def patch_quote(quote, quote_params: {}, revision_params: {}, step: 1, commit: "save")
    patch staff_quotation_path(quote), params: {
      editor_step: step,
      commit: commit,
      quote: { lock_version: quote.reload.lock_version }.merge(quote_params),
      quote_revision: revision_params
    }
  end

  test "index requires permission and lists quotations" do
    quote = create_draft_quote
    get staff_quotations_path
    assert_response :success
    assert_select "h1", text: /Quotations/
    assert_includes response.body, quote.reference_number
    assert_select ".staff-enquiry-table .staff-enquiry-row__ref", text: quote.reference_number
    assert_select ".staff-enquiry-panel__footer .ant-pagination__summary", text: /quotations/
  end

  test "quotations index paginates" do
    26.times do |i|
      create_draft_quote.update_columns(created_at: i.minutes.ago)
    end

    get staff_quotations_path
    assert_response :success
    assert_select ".staff-enquiry-table tbody tr", count: 25
    assert_select ".ant-pagination__summary", text: /1–25 of /
    assert_select "a[rel=next]", text: "Next"

    get staff_quotations_path(page: 2)
    assert_select "a[rel=prev]", text: "Previous"
  end

  test "staff without quotes permission is denied" do
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))
    get staff_quotations_path
    assert_redirected_to root_path
  end

  test "anonymous visitors cannot reach quotations or PDFs" do
    quote = create_ready_quote
    sign_out
    get staff_quotations_path
    assert_response :redirect
    assert_no_match %r{/staff/quotations}, response.location
    get pdf_staff_quotation_path(quote)
    assert_response :redirect
    assert_not_equal "application/pdf", response.media_type
  end

  test "client users cannot reach staff quotations" do
    quote = create_ready_quote
    sign_in_as(users(:client_only), membership: memberships(:client_membership))
    get pdf_staff_quotation_path(quote)
    assert_not_equal "application/pdf", response.media_type
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

  test "editor renders all five steps in one form with plain pricing labels" do
    quote = create_ready_quote
    get edit_staff_quotation_path(quote, editor_step: 3)
    assert_response :success
    assert_select "form#quote-editor-form section[role=tabpanel]", 5
    assert_select "button[role=tab]", 5
    assert_select "label", text: "Unit price"
    assert_select "label", text: /cents/i, count: 0
    assert_select "input[name$='[unit_price]'][value='1,250.00']"
    assert_includes response.body, "GHS 2,500.00"
    # No automatically appended blank line item
    assert_select "ol[data-quote-pricing-target=list] > li", 1
  end

  test "an empty draft has no pricing rows and no required inputs" do
    quote = create_draft_quote
    get edit_staff_quotation_path(quote, editor_step: 3)
    assert_select "ol[data-quote-pricing-target=list] > li", 0
    assert_select "form#quote-editor-form [required]", 0
  end

  test "save client step persists draft data" do
    quote = create_draft_quote
    patch_quote(quote, quote_params: { prospective_client: { company_name: "Harbour Shipping Ltd", contact_name: "Ama Mensah", email: "procurement@example.test" } })
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 1)
    assert_equal "Harbour Shipping Ltd", quote.reload.prospective_value("company_name")
  end

  test "save and continue saves first then moves to the next step" do
    quote = create_draft_quote
    patch_quote(quote, revision_params: { title: "Dive survey" }, step: 2, commit: "save_continue")
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 3)
    assert_equal "Dive survey", quote.reload.current_revision.title
  end

  test "pricing converts ordinary amounts to minor units and supports add, reorder and remove" do
    quote = create_draft_quote
    patch_quote(quote, step: 3, revision_params: {
      currency: "GHS",
      line_items_attributes: {
        "0" => { description: "Inspection", quantity: "2", unit: "each", unit_price: "1,250.00", position: "1" },
        "1" => { description: "Mobilisation", quantity: "1", unit: "lot", unit_price: "300.5", position: "0" }
      }
    })
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 3)
    revision = quote.reload.current_revision
    items = revision.line_items.to_a
    assert_equal [ "Mobilisation", "Inspection" ], items.map(&:description)
    assert_equal [ 30_050, 125_000 ], items.map(&:unit_price_cents)
    assert_equal 250_000, items.last.line_total_cents
    assert_equal 280_050, revision.total_cents

    patch_quote(quote, step: 3, revision_params: {
      line_items_attributes: { "0" => { id: items.first.id, _destroy: "1" }, "1" => { id: items.last.id, position: "0" } }
    })
    revision.reload
    assert_equal [ "Inspection" ], revision.line_items.map(&:description)
    assert_equal 250_000, revision.total_cents
  end

  test "partial draft pricing saves without a description" do
    quote = create_draft_quote
    patch_quote(quote, step: 3, revision_params: { line_items_attributes: { "0" => { description: "", quantity: "1", unit: "each", unit_price: "99.99" } } })
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 3)
    assert_equal 9_999, quote.reload.current_revision.total_cents
  end

  test "invalid pricing is rejected atomically with friendly errors" do
    quote = create_draft_quote
    patch_quote(quote, quote_params: { prospective_client: { company_name: "Should Not Save" } }, step: 3, revision_params: {
      title: "Should not save either",
      line_items_attributes: {
        "0" => { description: "Bad price", quantity: "1", unit: "each", unit_price: "12.345" },
        "1" => { description: "Negative", quantity: "1", unit: "each", unit_price: "-5" },
        "2" => { description: "Bad qty", quantity: "0", unit: "each", unit_price: "5" },
        "3" => { description: "Huge", quantity: "1", unit: "each", unit_price: "99999999999" }
      }
    })
    assert_response :unprocessable_entity
    assert_includes response.body, "Use no more than 2 decimal places for the unit price."
    assert_includes response.body, "Unit price cannot be negative."
    assert_includes response.body, "Quantity must be greater than zero."
    assert_includes response.body, "Unit price is too large."
    # entered values stay visible
    assert_select "input[value='12.345']"
    quote.reload
    assert_equal "", quote.prospective_value("company_name")
    assert_equal 0, quote.current_revision.line_items.count
    assert_equal "", quote.current_revision.title.to_s
  end

  test "invalid edits to an existing pricing line are reported, not silently ignored" do
    quote = create_ready_quote
    item = quote.current_revision.line_items.first
    patch_quote(quote, step: 3, revision_params: { line_items_attributes: { "0" => { id: item.id, unit_price: "300.505", quantity: "1abc" } } })
    assert_response :unprocessable_entity
    assert_includes response.body, "Use no more than 2 decimal places for the unit price."
    assert_includes response.body, "Enter a quantity as a number"
    assert_equal 125_000, item.reload.unit_price_cents
    # Review and summary describe the saved version, not the rejected input
    assert_select "#quote-readiness", 0
    assert_includes response.body, "Everything needed for review is in place."
  end

  test "unsupported currency is rejected" do
    quote = create_draft_quote
    patch_quote(quote, step: 3, revision_params: { currency: "NGN" })
    assert_response :unprocessable_entity
    assert_includes response.body, "Choose a supported currency."
    assert_equal "GHS", quote.reload.current_revision.currency
  end

  test "forged client organisation and service ids are rejected" do
    quote = create_draft_quote
    patch_quote(quote, quote_params: { client_organization_id: organizations(:ant_marine).id })
    assert_response :unprocessable_entity
    assert_nil quote.reload.client_organization_id

    draft_service = Service.where.not(status: "published").first
    patch_quote(quote, quote_params: { service_id: draft_service.id }, step: 2)
    assert_response :unprocessable_entity
    assert_nil quote.reload.service_id
  end

  test "line item ids from another quotation cannot be tampered with" do
    other = create_ready_quote
    other_item = other.current_revision.line_items.first
    quote = create_draft_quote
    patch_quote(quote, step: 3, revision_params: { line_items_attributes: { "0" => { id: other_item.id, unit_price: "1.00" } } })
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 3)
    assert_match(/Nothing was saved/, flash[:alert])
    assert_equal 125_000, other_item.reload.unit_price_cents
  end

  test "stale lock version is rejected without partial changes" do
    quote = create_draft_quote
    stale_version = quote.lock_version
    patch_quote(quote, revision_params: { title: "First save" })
    patch staff_quotation_path(quote), params: {
      editor_step: 2,
      quote: { lock_version: stale_version, prospective_client: { company_name: "Late Co" } },
      quote_revision: { title: "Second save" }
    }
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 2)
    assert_match(/Someone else saved/, flash[:alert])
    quote.reload
    assert_equal "First save", quote.current_revision.title
    assert_equal "", quote.prospective_value("company_name")
  end

  test "incomplete quotation submission is refused with a checklist" do
    quote = create_draft_quote
    post submit_for_review_staff_quotation_path(quote)
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 5)
    assert_match(/Not submitted/, flash[:alert])
    assert_equal "draft", quote.reload.status
    follow_redirect!
    assert_select "#quote-readiness li", minimum: 5
  end

  test "full journey: submit, approve, PDF; editing blocked during review" do
    quote = create_ready_quote
    post submit_for_review_staff_quotation_path(quote)
    assert_equal "pending_review", quote.reload.status

    patch_quote(quote, revision_params: { title: "Edited during review" }, step: 2)
    assert_redirected_to root_path
    assert_equal "Hull inspection for MV Example", quote.reload.current_revision.title

    get edit_staff_quotation_path(quote, editor_step: 5)
    assert_select "#quote-editor-form fieldset[disabled]", 4
    assert_select "button", text: "Approve this version", count: 0
    assert_select "#quote-another-reviewer", text: /Another reviewer must approve this version/
    assert_includes response.body, "Pricing is read-only while the quotation is being reviewed."
    assert_not_includes response.body, "Approved total."

    # A forged request from the preparer is refused and recorded.
    assert_difference -> { AuditEvent.where(event_type: "quote.approval_refused").count }, 1 do
      post approve_staff_quotation_path(quote), params: reviewer_form_params(quote)
    end
    assert_match(/different reviewer must approve/, flash[:alert])
    assert_equal "pending_review", quote.reload.status

    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))
    get edit_staff_quotation_path(quote, editor_step: 5)
    assert_select "button", text: "Approve this version"
    assert_select "input[name=expected_revision_id][value='#{quote.current_revision_id}']"
    assert_select "input[name=expected_lock_version][value='#{quote.lock_version}']"

    post approve_staff_quotation_path(quote), params: reviewer_form_params(quote)
    assert_equal "approved_for_issuance", quote.reload.status
    assert_equal memberships(:ops_manager_membership).id, quote.current_revision.approved_by_membership_id
    assert_match(/has not been sent/, flash[:notice])

    get edit_staff_quotation_path(quote, editor_step: 5)
    assert_includes response.body, "Approved total. This version is locked."
    assert_includes response.body, "Approved — not sent"
    assert_includes response.body, "Not sent to the client"
    assert_select "button", text: /Issue to client|Mark as issued/, count: 0

    get pdf_staff_quotation_path(quote)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_match(/#{quote.reference_number}-v1\.pdf/, response.headers["Content-Disposition"])
  end

  test "frozen quotation rejects PATCH update" do
    quote = approve_quote!(create_ready_quote)
    patch_quote(quote, quote_params: { prospective_client: { company_name: "Evil Co" } }, revision_params: { title: "Changed" })
    assert_redirected_to root_path
    quote.reload
    assert_equal "Harbour Logistics Ltd", quote.prospective_value("company_name")
    assert_equal "Hull inspection for MV Example", quote.current_revision.title
  end

  test "reviewer without approval permission cannot approve or return" do
    quote = create_ready_quote
    post submit_for_review_staff_quotation_path(quote)
    deny_permission!(memberships(:ops_manager_membership), "quotes.approve")
    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))

    get edit_staff_quotation_path(quote, editor_step: 5)
    assert_select "button", text: "Approve this version", count: 0
    assert_select "#quote-another-reviewer", 0

    post approve_staff_quotation_path(quote), params: reviewer_form_params(quote)
    assert_equal "You do not have permission to do that.", flash[:alert]
    post return_for_correction_staff_quotation_path(quote), params: reviewer_form_params(quote).merge(reason: "Fix it")
    assert_equal "pending_review", quote.reload.status
  end

  test "super administrator who prepared a quotation cannot approve it" do
    sign_in_as(users(:super_admin), membership: memberships(:super_admin_membership))
    quote = create_ready_quote(membership: memberships(:super_admin_membership))
    post submit_for_review_staff_quotation_path(quote)

    get edit_staff_quotation_path(quote, editor_step: 5)
    assert_select "button", text: "Approve this version", count: 0
    assert_select "#quote-another-reviewer"

    post approve_staff_quotation_path(quote), params: reviewer_form_params(quote)
    assert_match(/different reviewer must approve/, flash[:alert])
    assert_equal "pending_review", quote.reload.status
  end

  test "approval without the reviewed version, or with an outdated one, changes nothing" do
    quote = create_ready_quote
    post submit_for_review_staff_quotation_path(quote)
    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))

    post approve_staff_quotation_path(quote)
    assert_match(/changed after you opened it/, flash[:alert])
    post approve_staff_quotation_path(quote), params: reviewer_form_params(quote).merge(expected_lock_version: 0)
    assert_match(/changed after you opened it/, flash[:alert])
    assert_equal "pending_review", quote.reload.status
    assert_nil quote.current_revision.frozen_at
  end

  test "return for correction, correction, resubmission and approval by another reviewer" do
    quote = create_ready_quote
    post submit_for_review_staff_quotation_path(quote)
    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))
    opened = reviewer_form_params(quote)
    post return_for_correction_staff_quotation_path(quote), params: opened.merge(reason: "Please add the dive team size.")
    assert_equal "returned_for_correction", quote.reload.status

    sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
    get edit_staff_quotation_path(quote, editor_step: 1)
    assert_includes response.body, "Please add the dive team size."
    patch_quote(quote, revision_params: { title: "Corrected title" }, step: 2)
    assert_equal "Corrected title", quote.reload.current_revision.title
    post submit_for_review_staff_quotation_path(quote)
    assert_equal "pending_review", quote.reload.status

    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))
    post approve_staff_quotation_path(quote), params: opened
    assert_match(/changed after you opened it/, flash[:alert])

    post approve_staff_quotation_path(quote), params: reviewer_form_params(quote)
    quote.reload
    assert_equal "approved_for_issuance", quote.status
    assert_equal "Corrected title", quote.current_revision.title
    assert_equal memberships(:ops_manager_membership).id, quote.current_revision.approved_by_membership_id
    assert_equal memberships(:dual_staff).id, quote.current_revision.prepared_by_membership_id
  end

  test "a reviewer who edits a returned quotation can no longer approve it" do
    quote = create_ready_quote
    post submit_for_review_staff_quotation_path(quote)
    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))
    post return_for_correction_staff_quotation_path(quote), params: reviewer_form_params(quote).merge(reason: "Shorten the title.")
    patch_quote(quote, revision_params: { title: "Reviewer edit" }, step: 2)
    assert_includes quote.reload.current_revision.contributor_membership_ids, memberships(:ops_manager_membership).id

    sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
    post submit_for_review_staff_quotation_path(quote)
    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))
    post approve_staff_quotation_path(quote), params: reviewer_form_params(quote)
    assert_match(/different reviewer must approve/, flash[:alert])
    assert_equal "pending_review", quote.reload.status
  end

  test "saving without changes does not make the person a contributor" do
    quote = create_ready_quote
    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))
    patch_quote(quote, revision_params: { title: quote.current_revision.title }, step: 2)
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 2)
    assert_equal [ memberships(:dual_staff).id ], quote.reload.current_revision.contributor_membership_ids
  end

  test "common units and a custom Other unit are saved; invalid custom units are refused" do
    quote = create_draft_quote
    patch_quote(quote, step: 3, revision_params: { line_items_attributes: {
      "0" => { description: "Diving day", quantity: "2", unit_choice: "day", unit_other: "", unit_price: "500" },
      "1" => { description: "Sediment", quantity: "3", unit_choice: "other", unit_other: "  tonne ", unit_price: "10" }
    } })
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 3)
    assert_equal %w[day tonne], quote.reload.current_revision.line_items.map(&:unit)

    get edit_staff_quotation_path(quote, editor_step: 3)
    assert_select "select[name$='[unit_choice]'] option[selected][value=day]"
    assert_select "select[name$='[unit_choice]'] option[selected][value=other]"
    assert_select "input[name$='[unit_other]'][value=tonne]"

    item = quote.current_revision.line_items.last
    [ [ "other", "" ], [ "other", "Other" ], [ "other", "<b>bad</b>" ], [ "fortnight", "" ] ].each do |choice, other|
      patch_quote(quote, step: 3, revision_params: { line_items_attributes: { "0" => { id: item.id, unit_choice: choice, unit_other: other } } })
      assert_response :unprocessable_entity, "#{choice}/#{other} should be refused"
      assert_equal "tonne", item.reload.unit
    end
    assert_includes response.body, "Choose a unit, or choose Other and type one."
  end

  test "older free-text units are shown as Other and kept unchanged when saved" do
    quote = create_ready_quote
    item = quote.current_revision.line_items.first
    item.update_columns(unit: "Per m^2 ")

    get edit_staff_quotation_path(quote, editor_step: 3)
    assert_select "select[name$='[unit_choice]'] option[selected][value=other]"
    assert_select "input[name$='[unit_other]'][value='Per m^2 ']"

    patch_quote(quote, step: 3, revision_params: { line_items_attributes: {
      "0" => { id: item.id, description: "Hull inspection (updated)", unit_choice: "other", unit_other: "Per m^2" }
    } })
    assert_redirected_to edit_staff_quotation_path(quote, editor_step: 3)
    item.reload
    assert_equal "Per m^2 ", item.unit
    assert_equal "Hull inspection (updated)", item.description
  end

  test "issue endpoint is gated and makes no delivery claim" do
    quote = approve_quote!(create_ready_quote)
    post issue_staff_quotation_path(quote)
    assert_equal Commercial::QuoteIssuance::UNAVAILABLE_MESSAGE, flash[:alert]
    quote.reload
    assert_equal "approved_for_issuance", quote.status
    assert_equal "not_prepared", quote.delivery_state
  end

  test "PDF of an approved version stays identical in content after unrelated draft edits elsewhere" do
    quote = approve_quote!(create_ready_quote)
    get pdf_staff_quotation_path(quote, version: 1)
    first = response.body.gsub(%r{/CreationDate \(.*?\)}, "")
    Quote.where(id: quote.id).update_all(prospective_client: { "company_name" => "Renamed" })
    get pdf_staff_quotation_path(quote, version: 1)
    assert_equal first, response.body.gsub(%r{/CreationDate \(.*?\)}, "")
  end

  test "draft PDF filename is marked as draft" do
    quote = create_draft_quote
    get pdf_staff_quotation_path(quote)
    assert_response :success
    assert_match(/-v1-DRAFT\.pdf/, response.headers["Content-Disposition"])
  end

  test "unknown PDF version is not found" do
    quote = create_draft_quote
    get pdf_staff_quotation_path(quote, version: 9)
    assert_response :not_found
  end

  test "refreshing GET new does not duplicate drafts" do
    assert_no_difference("Quote.count") do
      2.times { get new_staff_quotation_path }
    end
  end

  test "general staff cannot open editor" do
    quote = create_draft_quote
    sign_in_as(users(:staff_only), membership: memberships(:staff_membership))
    get edit_staff_quotation_path(quote)
    assert_response :not_found
  end
end
