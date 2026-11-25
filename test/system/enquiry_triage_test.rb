# frozen_string_literal: true

require "application_system_test_case"

class EnquiryTriageTest < ApplicationSystemTestCase
  include EnquiryTestHelper

  setup do
    @inquiry = submit_enquiry!
    @coordinator = create_staff_member!(role_key: "staff.project_coordinator", name: "Abena Coordinator")
  end

  test "a coordinator reviews, asks a question, records the answer and marks the enquiry ready to quote" do
    sign_in_through_form(@coordinator.user)

    visit staff_service_inquiries_path
    within(".staff-enquiry-table") { click_on "Open" }
    assert_selector "h1", text: "Harbour Logistics Ltd"

    click_on "Start review"
    assert_text "Review started"
    assert_selector ".staff-enquiry-owner", text: "Abena Coordinator"

    click_on "Ask a question"
    within("#dialog-clarification") do
      fill_in "Subject", with: "Vessel draught"
      fill_in "What do you need to know?", with: "What is the current draught?"
      click_on "Save request"
    end
    assert_text "Nothing has been sent"
    assert_text "Prepared — not sent to the client"

    click_on "Record contact"
    within("dialog[open]") do
      choose "Phone call"
      click_on "Record contact"
    end
    assert_selector ".ant-badge", text: "Awaiting information"

    click_on "Record answer"
    within("dialog[open]") do
      fill_in "Answer", with: "About 4.2 metres."
      choose "Phone call"
      click_on "Record answer"
    end
    assert_text "Client’s answer recorded."

    click_on "Mark ready to quote"
    within("#dialog-qualify") do
      fill_in "Scope note (optional)", with: "Scope confirmed."
      click_on "Mark ready to quote"
    end
    assert_text "Marked ready to quote."
    assert_selector ".ant-badge", text: "Ready to quote"
    assert_equal "qualified", @inquiry.reload.current_status
  end

  test "dialogs close with Escape and return focus to the button that opened them" do
    sign_in_through_form(@coordinator.user)

    visit staff_service_inquiry_path(@inquiry)
    click_on "Close enquiry"
    assert_selector "#dialog-close[open]"
    find("#dialog-close").send_keys(:escape)
    assert_no_selector "#dialog-close[open]"
    assert_equal "Close enquiry", page.evaluate_script("document.activeElement.textContent").strip
  end
end
