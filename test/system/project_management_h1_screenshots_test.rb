# frozen_string_literal: true

require "application_system_test_case"

class ProjectManagementH1ScreenshotsTest < ApplicationSystemTestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @owner = memberships(:client_owner_membership)
    pack = build_accepted_project!(staff: @staff, owner: @owner, idempotency_key: "f405-h1-shots")
    @project = pack[:project]
    @dir = Rails.root.join("tmp/f405_h1_screens")
    FileUtils.mkdir_p(@dir)
  end

  test "capture staff and client project screens at key widths" do
    sign_in_through_form(@staff.user, password: "password")

    visit staff_projects_path
    assert_text(/Projects|Simulated/i)
    capture_widths("staff_projects_index")

    visit staff_project_path(@project)
    assert_text @project.reference_number
    capture_widths("staff_project_overview")

    visit staff_project_path(@project, tab: "team")
    capture_widths("staff_project_team", widths: [ 1280, 390 ])

    visit staff_project_path(@project, tab: "tasks")
    capture_widths("staff_project_tasks", widths: [ 1280, 390 ])

    visit staff_project_path(@project, tab: "milestones")
    page.save_screenshot(@dir.join("staff_project_milestones_1280.png").to_s)

    visit staff_project_path(@project, tab: "schedule")
    page.save_screenshot(@dir.join("staff_project_schedule_1280.png").to_s)

    visit staff_tasks_path
    capture_widths("staff_my_tasks", widths: [ 1280, 390 ])

    Capybara.reset_sessions!
    sign_in_through_form(@owner.user, password: "password")

    visit client_projects_path
    assert_text @project.reference_number
    capture_widths("client_projects_index")

    visit client_project_path(@project)
    assert_text(/Simulated/i)
    capture_widths("client_project_detail")
  end

  private

    def capture_widths(name, widths: [ 1440, 1280, 768, 390 ])
      widths.each do |width|
        page.driver.browser.manage.window.resize_to(width, 900)
        page.save_screenshot(@dir.join("#{name}_#{width}.png").to_s)
      end
      page.driver.browser.manage.window.resize_to(1280, 900)
    end
end
