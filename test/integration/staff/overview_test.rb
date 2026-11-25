# frozen_string_literal: true

require "test_helper"

module Staff
  class OverviewTest < ActionDispatch::IntegrationTest
    include SessionTestHelper
    include EnquiryTestHelper
    include QuoteTestHelper

    test "a coordinator sees enquiry counts, assigned work and notifications from their own organisation" do
      inquiry = submit_enquiry!
      assign_enquiry!(inquiry, memberships(:dual_staff))
      quote = create_ready_quote
      Commercial::QuoteTransition.apply!(quote: quote, action: :submit_for_review, membership: memberships(:dual_staff))

      sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
      get staff_root_path

      assert_response :success
      assert_select "h1", text: /Good (morning|afternoon|evening)/
      assert_select ".staff-enquiry-stat[aria-label^=?]", "New enquiries:"
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Assigned to me: 1"
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Waiting for your approval: 0"
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Unread notifications:"
      assert_select "#overview-work-heading", text: "Work waiting for you"
      assert_select ".staff-overview-row__title", text: "Harbour Logistics Ltd"
      assert_select ".staff-overview-row__detail", text: /Enquiry #{inquiry.reference_number}/
      assert_select "a", text: "View enquiries"
      assert_select "a", text: "Quotations"
    end

    test "an operations manager sees quotations waiting for independent approval and team access" do
      quote = create_ready_quote
      Commercial::QuoteTransition.apply!(quote: quote, action: :submit_for_review, membership: memberships(:dual_staff))

      sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))
      get staff_root_path

      assert_response :success
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Waiting for your approval: 1"
      assert_select ".staff-overview-row .ant-badge", text: "Needs your approval"
      assert_select "#overview-access-heading", text: "Team access"
    end

    test "general staff only see assigned work and have no team enquiry or quotation cards" do
      inquiry = submit_enquiry!
      surveyor = create_staff_member!(role_key: "staff.general_staff", name: "Ama General")
      assign_enquiry!(inquiry, surveyor)
      create_ready_quote

      sign_in_as(surveyor.user)
      get staff_root_path

      assert_response :success
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Assigned to me: 1"
      assert_select ".staff-enquiry-stat[aria-label^=?]", "New enquiries:", count: 0
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Waiting for your approval:", count: 0
      assert_select ".staff-overview-row__title", text: "Harbour Logistics Ltd"
      assert_select "a", text: "View enquiries"
      assert_select "a", text: "Quotations", count: 0
      assert_select "#overview-access-heading", count: 0
    end

    test "a finance officer sees notifications only — no enquiry or quotation work" do
      submit_enquiry!
      create_ready_quote
      finance = create_staff_member!(role_key: "staff.finance_officer", name: "Kwesi Finance")

      sign_in_as(finance.user)
      get staff_root_path

      assert_response :success
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Unread notifications:"
      assert_select ".staff-enquiry-stat[aria-label^=?]", "New enquiries:", count: 0
      assert_select ".staff-enquiry-stat[aria-label^=?]", "Assigned to me:", count: 0
      assert_select "#overview-work-heading"
      assert_select ".staff-overview-empty", text: "Nothing is waiting for you."
      assert_select "a", text: "View enquiries", count: 0
      assert_select "a", text: "Quotations", count: 0
    end

    test "overview never shows an enquiry that belongs to another organisation" do
      foreign = submit_enquiry!(company_name: "Secret Shipping", contact_email: "hidden@secret.example")
      # Enquiries are always created against ANT Marine; move the row to prove the overview is scoped.
      foreign.update_columns(organization_id: organizations(:acme_client).id)
      StaffNotification.where(subject_type: "ServiceInquiry", subject_id: foreign.id).delete_all

      sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
      get staff_root_path

      assert_response :success
      assert_select ".staff-overview-row__title", text: "Secret Shipping", count: 0
      assert_select ".staff-enquiry-stat[aria-label^=?]", "New enquiries: 0"
      assert_not_includes response.body, foreign.reference_number
    end

    test "empty overview shows calm empty states" do
      StaffNotification.where(recipient_membership_id: memberships(:dual_staff).id).delete_all
      sign_in_as(users(:dual_domain), membership: memberships(:dual_staff))
      get staff_root_path

      assert_response :success
      assert_select ".staff-overview-empty", text: "Nothing is waiting for you."
      assert_select ".staff-overview-empty", text: "No updates yet."
    end
  end
end
