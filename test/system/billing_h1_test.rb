# frozen_string_literal: true

require "application_system_test_case"

class BillingH1Test < ApplicationSystemTestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @dir = Rails.root.join("tmp/f408_screens")
    FileUtils.mkdir_p(@dir)
  end

  test "finance invoice issue release payment and client download journey" do
    project = build_accepted_project!(staff: @staff, owner: @client, idempotency_key: "f408-sys")[:project]
    finance = create_staff_membership!(role_key: "staff.finance_officer", password: "password")

    sign_in_through_form(finance.user, password: "password")
    visit staff_finance_path
    assert_text(/Bills|Simulated/i)
    page.save_screenshot(@dir.join("01_finance_dashboard_1280.png"))

    visit new_staff_invoice_path(project_id: project.id)
    assert_text(/Create invoice|Accepted amount|Remaining/i)
    assert_selector "#invoice_description"
    find("#invoice_description").set("Simulated partial invoice for F4-08 system QA")
    page.execute_script(<<~JS, (Date.current + 14).iso8601)
      const input = document.getElementById("invoice_due_on");
      if (input) {
        input.value = arguments[0];
        input.dispatchEvent(new Event("input", { bubbles: true }));
        input.dispatchEvent(new Event("change", { bubbles: true }));
      }
    JS
    find("#line_description").set("Initial payment")
    find("#line_quantity").set("1")
    find("#line_unit").set("Lot")
    find("#line_amount").set("1000.00")
    click_button "Save draft invoice"
    assert_text(/Draft|SIMULATED|ANT-INV/i)
    page.save_screenshot(@dir.join("02_draft_created_1280.png"))

    invoice = project.invoices.order(:id).last
    assert invoice.present?, "Expected draft invoice to exist"
    assert_text invoice.reference_number
    assert invoice.due_on.present?, "Draft must retain a due date for issuance"

    click_button "Issue invoice"
    assert_text(/Issued|SIMULATED/i)
    assert_no_text "Set a due date before issuing"
    page.save_screenshot(@dir.join("03_issued_1280.png"))

    assert_button "Release to client"
    click_button "Release to client"
    assert_text(/Released|client/i)
    page.save_screenshot(@dir.join("04_released_1280.png"))

    find("#payment_amount").set("400.00")
    find("#payment_ref").set("QA-SYS-PAY-1")
    page.execute_script(<<~JS, Date.current.iso8601)
      const input = document.getElementById("payment_payment_on");
      if (input) {
        input.value = arguments[0];
        input.dispatchEvent(new Event("input", { bubbles: true }));
        input.dispatchEvent(new Event("change", { bubbles: true }));
      }
    JS
    click_button "Record payment"
    assert_text(/Partially paid|400|Recorded/i)
    page.save_screenshot(@dir.join("05_partial_payment_1280.png"))

    page.current_window.resize_to(390, 844)
    sign_in_through_form(@client.user, password: "password")
    visit client_invoices_path
    assert_text(/Bills|SIMULATED/i)
    assert_text invoice.reference_number
    page.save_screenshot(@dir.join("06_client_bills_390.png"))
    click_on invoice.reference_number
    assert_text(/Outstanding|SIMULATED|not payable/i)
    page.save_screenshot(@dir.join("07_client_invoice_390.png"))
    assert_link "Download bill"

    page.current_window.resize_to(1280, 900)
    other = create_staff_membership!(role_key: "staff.surveyor", password: "password")
    sign_in_through_form(other.user, password: "password")
    visit staff_finance_path
    assert_no_current_path staff_finance_path
    page.save_screenshot(@dir.join("08_surveyor_denied_1280.png"))
  end
end
