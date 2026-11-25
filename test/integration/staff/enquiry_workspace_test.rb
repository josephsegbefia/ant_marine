# frozen_string_literal: true

require "test_helper"

module Staff
  class EnquiryWorkspaceTest < ActionDispatch::IntegrationTest
    include SessionTestHelper
    include EnquiryTestHelper
    include QuoteTestHelper
    include ActionMailer::TestHelper

    setup do
      @inquiry = submit_enquiry!
      @coordinator = memberships(:dual_staff)
    end

    def version
      ServiceInquiry.find(@inquiry.id).lock_version
    end

    def transition(step, **params)
      post transition_staff_service_inquiry_path(@inquiry), params: { step: step, expected_lock_version: version, **params }
    end

    # Inbox

    test "inbox shows summary counts, views and filters from the person's own scope" do
      ready = submit_enquiry!(company_name: "Coastline Operations", contact_email: "ops@coastline.example")
      triage!(ready, "qualify")
      closed = submit_enquiry!(company_name: "Old Request Co", contact_email: "old@request.example")
      triage!(closed, "close", closure_reason: "cancelled")
      sign_in_as(@coordinator.user)

      get staff_service_inquiries_path
      assert_response :success
      assert_select ".staff-enquiry-stat[aria-label^=?]", "New: 1"
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Ready to quote: 1"
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Unassigned: 2"
      assert_select ".ant-section-tabs__tab--active", text: "All enquiries"
      assert_select ".staff-enquiry-table tbody tr", count: 3

      get staff_service_inquiries_path(view: "closed")
      assert_select ".staff-enquiry-table .staff-enquiry-row__company", text: "Old Request Co"
      assert_select ".staff-enquiry-table tbody tr", count: 1

      get staff_service_inquiries_path(q: "ops@coastline")
      assert_select ".staff-enquiry-table tbody tr", count: 1
      assert_select ".staff-enquiry-table .staff-enquiry-row__company", text: "Coastline Operations"

      get staff_service_inquiries_path(status: "submitted")
      assert_select ".staff-enquiry-table .staff-enquiry-row__company", text: "Harbour Logistics Ltd"
      assert_select ".staff-enquiry-table tbody tr", count: 1

      get staff_service_inquiries_path(from: (Date.current + 1).iso8601)
      assert_select ".staff-enquiry-table", count: 0
      assert_select "h2", text: "No enquiries match these filters"
      assert_select "a", text: "Clear filters"
    end

    test "assigned and unassigned views and the responsible-person filter" do
      other = submit_enquiry!(company_name: "Second Harbour", contact_email: "second@harbour.example")
      assign_enquiry!(other, @coordinator)
      sign_in_as(@coordinator.user)

      get staff_service_inquiries_path(view: "mine")
      assert_select ".staff-enquiry-table .staff-enquiry-row__company", text: "Second Harbour"
      assert_select ".staff-enquiry-table tbody tr", count: 1

      get staff_service_inquiries_path(view: "unassigned")
      assert_select ".staff-enquiry-table .staff-enquiry-row__company", text: "Harbour Logistics Ltd"
      assert_select ".staff-enquiry-table tbody tr", count: 1

      get staff_service_inquiries_path(assignee: @coordinator.id)
      assert_select ".staff-enquiry-table tbody tr", count: 1

      get staff_service_inquiries_path(assignee: memberships(:client_owner_membership).id, status: "bogus", from: "not-a-date")
      assert_response :success
      assert_select ".staff-enquiry-table tbody tr", count: 2
    end

    test "inbox paginates" do
      26.times { |i| submit_enquiry!(company_name: "Bulk Company #{i}", contact_email: "bulk#{i}@example.com") }
      sign_in_as(@coordinator.user)

      get staff_service_inquiries_path
      assert_select ".staff-enquiry-table tbody tr", count: 25
      assert_select ".ant-pagination__summary", text: /1–25 of 27 enquiries/

      get staff_service_inquiries_path(page: 2)
      assert_select ".staff-enquiry-table tbody tr", count: 2
      assert_select "a[rel=prev]", text: "Previous"
    end

    test "staff who see only assigned enquiries get no team views and never see other enquiries" do
      surveyor = create_staff_member!(role_key: "staff.surveyor")
      mine = submit_enquiry!(company_name: "Assigned Marine", contact_email: "assigned@marine.example")
      assign_enquiry!(mine, surveyor)
      sign_in_as(surveyor.user)

      get staff_service_inquiries_path(view: "unassigned")
      assert_response :success
      assert_select ".ant-section-tabs__tab", text: "Unassigned", count: 0
      assert_select ".staff-enquiry-stat", text: /Unassigned/, count: 0
      assert_select ".staff-enquiry-table tbody tr", count: 1
      assert_select ".staff-enquiry-table .staff-enquiry-row__company", text: "Assigned Marine"
      assert_select "select#assignee", count: 0

      get staff_service_inquiry_path(@inquiry)
      assert_response :not_found

      get staff_service_inquiry_path(mine)
      assert_response :success
      assert_select "#enquiry-actions-heading", count: 0
      assert_select "form[action=?]", assign_staff_service_inquiry_path(mine), count: 0
      assert_select "form[action=?]", staff_service_inquiry_notes_path(mine)
    end

    # Detail workspace

    test "the workspace shows only the next steps that are allowed now" do
      sign_in_as(@coordinator.user)
      get staff_service_inquiry_path(@inquiry)
      assert_select "button", text: "Start review"
      assert_select "button", text: "Mark ready to quote"
      assert_select "button", text: "Reopen enquiry", count: 0
      assert_select ".staff-quote-notice", text: /recommend marking the enquiry ready to quote/
      assert_select "form[action=?]", assign_staff_service_inquiry_path(@inquiry)

      triage!(@inquiry, "close", closure_reason: "not_proceeding")
      get staff_service_inquiry_path(@inquiry)
      assert_select "button", text: "Reopen enquiry"
      assert_select "button", text: "Start review", count: 0
      assert_select "button", text: "Close enquiry", count: 0
      assert_select "button", text: "Prepare quotation", count: 0
      assert_select "dd", text: "Client is no longer proceeding"
    end

    test "workspace lists withdrawn quotations and the open one with derived progress" do
      sign_in_as(@coordinator.user)
      post prepare_quotation_staff_service_inquiry_path(@inquiry)
      quote = Quote.order(:id).last

      get staff_service_inquiry_path(@inquiry)
      assert_select "#enquiry-quotations", text: /#{quote.reference_number}/
      assert_select "#enquiry-quotations", text: /Draft being prepared/
      assert_select "a", text: "Open quotation"

      get staff_service_inquiries_path
      assert_select ".staff-enquiry-table .staff-enquiry-row__quote", text: "Quotation #{quote.reference_number} — draft being prepared"
    end

    # Transitions

    test "start review moves the enquiry on and makes the reviewer responsible" do
      sign_in_as(@coordinator.user)
      transition("start_review")
      assert_redirected_to staff_service_inquiry_path(@inquiry)
      assert_equal "Review started. You are now responsible for this enquiry if nobody else was.", flash[:notice]
      @inquiry.reload
      assert_equal "under_review", @inquiry.current_status
      assert_equal @coordinator, @inquiry.assigned_membership
    end

    test "qualify can link an existing client organisation but never one outside the list" do
      sign_in_as(@coordinator.user)
      transition("qualify", client_organization_id: organizations(:ant_marine).id)
      assert_match(/active client organisation/, flash[:alert])
      assert_equal "submitted", @inquiry.reload.current_status

      transition("qualify", note: "Scope confirmed by phone.", client_organization_id: organizations(:acme_client).id)
      assert_equal "Marked ready to quote.", flash[:notice]
      @inquiry.reload
      assert_equal "qualified", @inquiry.current_status
      assert_equal organizations(:acme_client), @inquiry.client_organization
      assert_equal 0, Membership.where(organization: organizations(:acme_client), user: User.where(email: @inquiry.contact_email)).count
    end

    test "close needs a reason, then reopen needs a reason and restores review" do
      sign_in_as(@coordinator.user)
      transition("close", closure_reason: "other")
      assert_equal "Explain the reason for closing.", flash[:alert]
      assert @inquiry.reload.open?

      transition("close", closure_reason: "other", note: "Client merged with another firm.")
      assert_equal "Enquiry closed.", flash[:notice]
      assert_equal "closed", @inquiry.reload.current_status

      transition("reopen")
      assert_equal "Explain why the enquiry is being reopened.", flash[:alert]

      transition("reopen", reason: "Client called back.")
      assert_equal "under_review", @inquiry.reload.current_status
      assert_nil @inquiry.closure_reason
    end

    test "closing is refused while a quotation is still open" do
      sign_in_as(@coordinator.user)
      post prepare_quotation_staff_service_inquiry_path(@inquiry)
      transition("close", closure_reason: "cancelled")
      assert_match(/still open for this enquiry/, flash[:alert])
      assert @inquiry.reload.open?
      assert_equal "draft", Quote.order(:id).last.status
    end

    test "a stale page cannot change the enquiry" do
      sign_in_as(@coordinator.user)
      stale = version
      triage!(@inquiry, "start_review")
      post transition_staff_service_inquiry_path(@inquiry), params: { step: "close", closure_reason: "cancelled", expected_lock_version: stale }
      assert_equal Intake::TriageGuard::STALE_MESSAGE, flash[:alert]
      assert_equal "under_review", @inquiry.reload.current_status
    end

    test "internal or unknown steps cannot be forced through the form" do
      sign_in_as(@coordinator.user)
      %w[await_information information_received destroy].each do |step|
        transition(step)
        assert_equal "That action is not available.", flash[:alert]
      end
      assert_equal "submitted", @inquiry.reload.current_status
    end

    test "mark as duplicate links to an enquiry in scope and keeps both requests" do
      original = submit_enquiry!(company_name: "Harbour Logistics Ltd")
      sign_in_as(@coordinator.user)

      get staff_service_inquiry_path(@inquiry)
      assert_select ".staff-enquiry-related a", text: original.reference_number

      transition("mark_duplicate", duplicate_reference: "ANT-ENQ-1999-00001")
      assert_match(/No enquiry with reference/, flash[:alert])

      transition("mark_duplicate", duplicate_reference: original.reference_number.downcase)
      assert_equal "Marked as a duplicate. The original request is kept unchanged.", flash[:notice]
      @inquiry.reload
      assert_equal "merged", @inquiry.current_status
      assert_equal original, @inquiry.duplicate_of
      assert_equal "We need an underwater hull inspection before our charter renewal.", @inquiry.description

      get staff_service_inquiry_path(original)
      assert_select ".staff-enquiry-related a", text: @inquiry.reference_number
    end

    test "people who can only see assigned enquiries cannot change status even when assigned" do
      surveyor = create_staff_member!(role_key: "staff.surveyor")
      assign_enquiry!(@inquiry, surveyor)
      sign_in_as(surveyor.user)
      transition("close", closure_reason: "cancelled")
      assert_redirected_to root_path
      assert_equal "submitted", @inquiry.reload.current_status
    end

    test "finance staff, clients and anonymous visitors cannot change enquiries" do
      finance = create_staff_member!(role_key: "staff.finance_officer")
      sign_in_as(finance.user)
      transition("close", closure_reason: "cancelled")
      assert_response :not_found
      get staff_service_inquiry_path(@inquiry)
      assert_response :not_found

      sign_in_as(memberships(:client_owner_membership).user)
      transition("close", closure_reason: "cancelled")
      assert_response :redirect
      assert_no_match %r{/staff/}, response.location.to_s

      reset!
      transition("close", closure_reason: "cancelled")
      assert_redirected_to new_session_path
      assert @inquiry.reload.open?
    end

    # Assignment

    test "assigning, reassigning with a reason and refusing invalid people" do
      colleague = create_staff_member!(role_key: "staff.surveyor", name: "Esi Surveyor")
      sign_in_as(@coordinator.user)

      post assign_staff_service_inquiry_path(@inquiry), params: { assignee_id: colleague.id, expected_lock_version: version }
      assert_equal "Esi Surveyor is now responsible for this enquiry.", flash[:notice]

      post assign_staff_service_inquiry_path(@inquiry), params: { assignee_id: @coordinator.id, expected_lock_version: version }
      assert_equal "Explain why responsibility is changing.", flash[:alert]
      assert_equal colleague, @inquiry.reload.assigned_membership

      post assign_staff_service_inquiry_path(@inquiry),
           params: { assignee_id: memberships(:client_owner_membership).id, reason: "Try", expected_lock_version: version }
      assert_equal "Choose an active team member who can work on enquiries.", flash[:alert]

      post assign_staff_service_inquiry_path(@inquiry),
           params: { assignee_id: @coordinator.id, reason: "Esi is on leave.", expected_lock_version: version }
      assert_equal @coordinator, @inquiry.reload.assigned_membership
      assert_equal 2, @inquiry.assignments.count
    end

    test "people without assignment permission cannot assign" do
      surveyor = create_staff_member!(role_key: "staff.surveyor")
      assign_enquiry!(@inquiry, surveyor)
      sign_in_as(surveyor.user)
      post assign_staff_service_inquiry_path(@inquiry), params: { assignee_id: "", reason: "Not mine", expected_lock_version: version }
      assert_redirected_to root_path
      assert_equal surveyor, @inquiry.reload.assigned_membership
    end

    # Notes

    test "notes are added, corrected without losing the original and kept out of quotations and PDFs" do
      sign_in_as(@coordinator.user)
      post staff_service_inquiry_notes_path(@inquiry), params: { body: "Client prefers a Saturday start — margin is tight." }
      assert_equal "Internal note added.", flash[:notice]
      note = @inquiry.notes.last

      post correct_staff_service_inquiry_note_path(@inquiry, note), params: { body: "Client prefers a Monday start." }
      assert_equal "Correction added. The original note is kept in the history.", flash[:notice]
      post correct_staff_service_inquiry_note_path(@inquiry, note), params: { body: "Third try" }
      assert_equal "This note has already been corrected.", flash[:alert]

      get staff_service_inquiry_path(@inquiry)
      assert_select ".staff-enquiry-note-item", text: /Saturday start/
      assert_select ".staff-enquiry-note-item", text: /Monday start/
      assert_select ".ant-timeline__title", text: /note/i

      post staff_service_inquiry_notes_path(@inquiry), params: { body: "   " }
      assert flash[:alert].present?

      post prepare_quotation_staff_service_inquiry_path(@inquiry)
      quote = Quote.order(:id).last
      revision = quote.current_revision
      [ revision.internal_notes, revision.scope_description, revision.title, quote.attributes.to_json ].each do |text|
        assert_not_includes text.to_s, "Saturday start"
        assert_not_includes text.to_s, "Monday start"
      end
      pdf = extract_pdf_text(Commercial::QuotePdfRenderer.render(quote: quote))
      assert_not_includes pdf, "Saturday start"
      assert_not_includes pdf, "Monday start"
    end

    test "notes cannot be added to an enquiry outside the person's scope" do
      surveyor = create_staff_member!(role_key: "staff.surveyor")
      sign_in_as(surveyor.user)
      assert_no_difference -> { ServiceInquiryNote.count } do
        post staff_service_inquiry_notes_path(@inquiry), params: { body: "Should not save" }
      end
      assert_response :not_found
    end

    # Clarifications

    test "clarification cycle records contact and answer without sending anything" do
      sign_in_as(@coordinator.user)
      assert_no_emails do
        post staff_service_inquiry_clarifications_path(@inquiry),
             params: { subject: "Vessel draught", questions: "What is the current draught?", prepared_message: "Hello Ama" }
        assert_match(/Nothing has been sent/, flash[:notice])
        clarification = @inquiry.clarifications.last
        assert_equal "submitted", @inquiry.reload.current_status

        get staff_service_inquiry_path(@inquiry)
        assert_select ".staff-enquiry-clarification", text: /Prepared — not sent to the client/

        post record_contact_staff_service_inquiry_clarification_path(@inquiry, clarification), params: { channel: "fax" }
        assert_equal "Choose how you contacted the client.", flash[:alert]

        post record_contact_staff_service_inquiry_clarification_path(@inquiry, clarification), params: { channel: "phone" }
        assert_equal "needs_clarification", @inquiry.reload.current_status

        post record_response_staff_service_inquiry_clarification_path(@inquiry, clarification),
             params: { response_text: "About 4.2 metres.", source: "phone", received_on: (Date.current + 3).iso8601 }
        assert flash[:alert].present?

        post record_response_staff_service_inquiry_clarification_path(@inquiry, clarification),
             params: { response_text: "About 4.2 metres.", source: "phone", received_on: Date.current.iso8601 }
        assert_equal "Client’s answer recorded.", flash[:notice]
        assert_equal "under_review", @inquiry.reload.current_status
        assert_equal "answered", clarification.reload.status
      end
    end

    test "clarifications cannot be managed by people without review permission" do
      surveyor = create_staff_member!(role_key: "staff.surveyor")
      assign_enquiry!(@inquiry, surveyor)
      sign_in_as(surveyor.user)
      assert_no_difference -> { ServiceInquiryClarification.count } do
        post staff_service_inquiry_clarifications_path(@inquiry), params: { subject: "X", questions: "Y" }
      end
      assert_redirected_to root_path
    end
  end
end
