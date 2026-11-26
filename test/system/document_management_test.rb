# frozen_string_literal: true

require "application_system_test_case"

class DocumentManagementTest < ApplicationSystemTestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @project = build_accepted_project!(staff: @staff, owner: @client, idempotency_key: "f406-system")[:project]
    FileUtils.mkdir_p(Rails.root.join("tmp/f406_screens"))
  end

  test "staff uploads document and sees quarantine messaging" do
    sign_in_through_form(@staff.user, password: "password")

    visit staff_project_path(@project)
    click_on "Documents"
    assert_text "Documents"

    click_on "Upload file"
    fill_in "Title", with: "Survey instruction pack"
    select "Other project file", from: "Category"
    attach_file "File", Rails.root.join("test/fixtures/files/sample.txt")
    click_on "Upload"

    assert_text "Survey instruction pack"
    assert_match(/security checks/i, page.text)
    page.save_screenshot(Rails.root.join("tmp/f406_screens/staff_document_quarantine.png"))
  end

  test "client opens files we need" do
    sign_in_through_form(@client.user, password: "password")
    visit client_project_upload_requests_path(@project)
    assert_text "Files we need"
    page.save_screenshot(Rails.root.join("tmp/f406_screens/client_files_we_need.png"))
  end
end
