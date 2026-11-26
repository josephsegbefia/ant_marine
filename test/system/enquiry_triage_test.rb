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
    # Prefer the dialog trigger (not the submit button inside the closed dialog). Sticky
    # aside / toast overlays can intercept mid-panel clicks — scroll and dismiss first.
    page.all(".ant-toast__dismiss", minimum: 0).each(&:click)
    trigger = find("#dialog-close-trigger, [data-ant-dialog-target='trigger'][aria-controls='dialog-close'], button[aria-controls='dialog-close']", match: :first)
    page.execute_script("arguments[0].scrollIntoView({block:'center'})", trigger.native)
    trigger.click
    assert_selector "#dialog-close[open]"
    find("#dialog-close").send_keys(:escape)
    assert_no_selector "#dialog-close[open]"
    assert_includes page.evaluate_script("document.activeElement.textContent").to_s, "Close enquiry"
  end

  test "staff can filter with the shared dropdown and date picker" do
    older = submit_enquiry!(company_name: "Older Co", contact_email: "older@example.com")
    older.update_columns(submitted_at: 5.days.ago)
    sign_in_through_form(@coordinator.user)
    visit staff_service_inquiries_path

    within('[data-controller="custom-select"]', match: :first) do
      find(".ant-select__trigger").click
      find('[role="option"]', text: "New").click
    end
    assert_equal "submitted", find("#status", visible: :all).value

    within('[data-controller="ant-date-picker"]', match: :first) do
      find(".ant-date__trigger").click
    end
    assert_selector ".ant-date__dialog[open]"
    within(".ant-date__dialog[open]") do
      click_on "Today"
    end
    assert_equal Date.current.iso8601, find("#from", visible: :all).value

    click_on "Apply"
    assert_selector ".staff-enquiry-row__company", text: "Harbour Logistics Ltd"
    assert_no_selector ".staff-enquiry-row__company", text: "Older Co"
  end
end
