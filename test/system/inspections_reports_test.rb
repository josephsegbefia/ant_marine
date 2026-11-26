# frozen_string_literal: true

require "application_system_test_case"

class InspectionsReportsTest < ApplicationSystemTestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    FileUtils.mkdir_p(Rails.root.join("tmp/f407_screens"))
  end

  test "staff opens inspections index and client reports empty" do
    sign_in_through_form(@staff.user, password: "password")
    visit staff_inspections_path
    assert_text "Inspections"
    page.save_screenshot(Rails.root.join("tmp/f407_screens/staff_inspections_index.png"))

    sign_in_through_form(@client.user, password: "password")
    visit client_reports_path
    assert_text "No reports shared yet"
    page.save_screenshot(Rails.root.join("tmp/f407_screens/client_reports_empty.png"))
  end

  test "staff prepares inspection and surveyor records checklist on mobile width" do
    project = build_accepted_project!(staff: @staff, owner: @client)[:project]
    surveyor = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: project,
      membership: surveyor,
      assignment_kind: "surveyor"
    )

    sign_in_through_form(@staff.user, password: "password")
    visit new_staff_inspection_path(project_id: project.id)
    assert_text "New inspection"
    fill_in "Title", with: "Simulated hull observation"
    fill_in "Inspection type", with: "general_observation"
    click_button "Create inspection"
    assert_text "ANT-INS-"
    page.save_screenshot(Rails.root.join("tmp/f407_screens/staff_inspection_created.png"))

    inspection = project.inspections.order(:id).last
    inspection.update!(assigned_surveyor_membership: surveyor, status: "assigned")

    page.driver.browser.manage.window.resize_to(390, 844)
    Capybara.reset_sessions!
    sign_in_through_form(surveyor.user, password: "Secure-password-123")
    visit staff_inspection_path(inspection)
    assert_text inspection.title
    assert_text "Checklist"
    page.save_screenshot(Rails.root.join("tmp/f407_screens/surveyor_workspace_390.png"))

    first("input[type='submit'][value='Save answer']").click if page.has_button?("Save answer")
    assert_text "Checklist"

    page.driver.browser.manage.window.resize_to(1280, 800)
    visit staff_reports_path
    assert_text "Reports"
    page.save_screenshot(Rails.root.join("tmp/f407_screens/staff_reports_index.png"))
  end
end
