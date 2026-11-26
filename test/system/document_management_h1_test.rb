# frozen_string_literal: true

require "application_system_test_case"

class DocumentManagementH1Test < ApplicationSystemTestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @project = build_accepted_project!(staff: @staff, owner: @client, idempotency_key: "f406-h1-system")[:project]
    FileUtils.mkdir_p(Rails.root.join("tmp/f406_h1_screens"))
  end

  test "staff upload shows security pending messaging" do
    sign_in_through_form(@staff.user, password: "password")

    visit staff_project_path(@project)
    click_on "Documents"
    assert_text "Documents"

    click_on "Upload file"
    fill_in "Title", with: "H1 security pending pack"
    select "Other project file", from: "Category"
    attach_file "File", Rails.root.join("test/fixtures/files/sample.txt")
    click_on "Upload"

    assert_text "H1 security pending pack"
    assert_match(/security checks/i, page.text)
    page.save_screenshot(Rails.root.join("tmp/f406_h1_screens/staff_document_quarantine.png"))
  end

  test "client sees files we need and project documents index" do
    sign_in_through_form(@client.user, password: "password")

    visit client_project_upload_requests_path(@project)
    assert_text "Files we need"
    page.save_screenshot(Rails.root.join("tmp/f406_h1_screens/client_files_we_need.png"))

    visit client_project_documents_path(@project)
    assert_text "Project documents"
    page.save_screenshot(Rails.root.join("tmp/f406_h1_screens/client_documents_index.png"))
  end

  test "responsive staff documents at 390px" do
    page.current_window.resize_to(390, 844)
    sign_in_through_form(@staff.user, password: "password")
    visit staff_project_documents_path(@project)
    assert_text "Project documents"
    click_on "Upload file"
    assert_text "Upload file"
    page.save_screenshot(Rails.root.join("tmp/f406_h1_screens/staff_documents_390.png"))
  ensure
    page.current_window.resize_to(1280, 900)
  end
end
