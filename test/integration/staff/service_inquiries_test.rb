# frozen_string_literal: true

require "test_helper"

module Staff
  class ServiceInquiriesTest < ActionDispatch::IntegrationTest
    include SessionTestHelper
    include EnquiryTestHelper
    include QuoteTestHelper

    setup do
      @inquiry = submit_enquiry!
    end

    test "staff with enquiry access see the list and the request details" do
      sign_in_as(memberships(:dual_staff).user)

      get staff_service_inquiries_path
      assert_response :success
      assert_select ".staff-nav-button", text: /Enquiries/
      assert_select ".ant-content-record__title", text: "Harbour Logistics Ltd"
      assert_select ".ant-content-record__guidance", text: "Not quoted yet"

      get staff_service_inquiry_path(@inquiry)
      assert_response :success
      assert_select "h1", text: "Harbour Logistics Ltd"
      assert_select "dd", text: "Takoradi port"
      assert_select "body", text: /not a confirmed booking/
      assert_select "button", text: "Prepare quotation"
    end

    test "staff without enquiry permission cannot list or open enquiries" do
      sign_in_as(memberships(:staff_membership).user)

      get staff_service_inquiries_path
      assert_redirected_to root_path

      get staff_service_inquiry_path(@inquiry)
      assert_response :not_found

      assert_no_difference -> { Quote.count } do
        post prepare_quotation_staff_service_inquiry_path(@inquiry)
      end
      assert_response :not_found
    end

    test "client users cannot reach staff enquiries" do
      sign_in_as(memberships(:client_owner_membership).user)
      get staff_service_inquiries_path
      assert_response :redirect
      assert_no_match %r{/staff/enquiries}, response.location.to_s
    end

    test "anonymous visitors are sent to sign in" do
      get staff_service_inquiry_path(@inquiry)
      assert_redirected_to new_session_path
    end

    test "prepare quotation carries client facts forward without inventing commercial terms" do
      sign_in_as(memberships(:dual_staff).user)

      assert_difference -> { Quote.count } => 1 do
        post prepare_quotation_staff_service_inquiry_path(@inquiry)
      end

      quote = Quote.order(:id).last
      assert_redirected_to edit_staff_quotation_path(quote, editor_step: 1)
      assert_equal @inquiry, quote.service_inquiry
      assert_equal services(:marine_surveys_published), quote.service
      assert_equal "Harbour Logistics Ltd", quote.prospective_value("company_name")
      assert_equal "Ama Mensah", quote.prospective_value("contact_name")
      assert_equal "ama@harbour.example", quote.prospective_value("email")
      assert_equal "draft", quote.status

      revision = quote.current_revision
      assert_equal "Published surveys — MV Example", revision.title
      assert_includes revision.internal_notes, @inquiry.reference_number
      assert_includes revision.internal_notes, "underwater hull inspection"
      assert_empty revision.line_items
      assert_nil revision.valid_until
      assert revision.scope_description.blank?
      assert revision.payment_terms.blank?
      assert revision.deliverables.blank?
      assert_equal memberships(:dual_staff), revision.prepared_by_membership

      assert AuditEvent.exists?(event_type: "quote.created_from_inquiry", subject_type: "Quote", subject_id: quote.id)
      assert AuditEvent.exists?(event_type: "service_inquiry.quotation_started", subject_id: @inquiry.id)

      follow_redirect!
      assert_select "#quote-source-enquiry a[href=?]", staff_service_inquiry_path(@inquiry), text: @inquiry.reference_number
    end

    test "repeating prepare quotation opens the existing quotation instead of creating another" do
      sign_in_as(memberships(:dual_staff).user)
      post prepare_quotation_staff_service_inquiry_path(@inquiry)
      first = Quote.order(:id).last

      assert_no_difference -> { Quote.count } do
        post prepare_quotation_staff_service_inquiry_path(@inquiry)
      end
      assert_redirected_to edit_staff_quotation_path(first, editor_step: 1)
      assert_equal "This enquiry already has a quotation in progress. Opened the existing quotation.", flash[:notice]

      get staff_service_inquiry_path(@inquiry)
      assert_select "a", text: "Open quotation"
      assert_select "button", text: "Prepare quotation", count: 0
    end

    test "enquiry viewer without quotation permission cannot prepare a quotation" do
      membership = memberships(:dual_staff)
      deny_permission!(membership, "quotes.create")
      sign_in_as(membership.user)

      get staff_service_inquiry_path(@inquiry)
      assert_select "button", text: "Prepare quotation", count: 0

      assert_no_difference -> { Quote.count } do
        post prepare_quotation_staff_service_inquiry_path(@inquiry)
      end
      assert_redirected_to root_path
    end

    test "closed enquiries cannot be converted" do
      @inquiry.update_columns(current_status: "closed")
      sign_in_as(memberships(:dual_staff).user)

      assert_no_difference -> { Quote.count } do
        post prepare_quotation_staff_service_inquiry_path(@inquiry)
      end
      assert_redirected_to root_path
    end

    test "unpublished service is not copied onto the quotation" do
      services(:marine_surveys_published).update_columns(status: "draft")
      result = Commercial::QuoteFromInquiry.call(inquiry: @inquiry, membership: memberships(:dual_staff))
      assert_nil result.quote.service
      assert_equal "Published surveys — MV Example", result.quote.current_revision.title
    end

    test "withdrawn quotation allows a fresh quotation for the same enquiry" do
      first = Commercial::QuoteFromInquiry.call(inquiry: @inquiry, membership: memberships(:dual_staff)).quote
      first.update_columns(status: "withdrawn")

      second = Commercial::QuoteFromInquiry.call(inquiry: @inquiry, membership: memberships(:dual_staff))
      assert second.created
      refute_equal first.id, second.quote.id
    end

    test "linked enquiry cannot be swapped on an existing quotation" do
      quote = Commercial::QuoteFromInquiry.call(inquiry: @inquiry, membership: memberships(:dual_staff)).quote
      other = submit_enquiry!(company_name: "Other Co")
      quote.service_inquiry = other
      refute quote.valid?
      assert_includes quote.errors[:base], "The enquiry linked to this quotation cannot be changed."
    end
  end
end
