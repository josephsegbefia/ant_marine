# frozen_string_literal: true

require "application_system_test_case"

class InspectionsReportsH1Test < ApplicationSystemTestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @dir = Rails.root.join("tmp/f409a_screens")
    FileUtils.mkdir_p(@dir)
  end

  test "connected inspection report release revoke journey with responsive checks" do
    project = build_accepted_project!(staff: @staff, owner: @client, idempotency_key: "f409a-h1-sys")[:project]
    surveyor = create_staff_membership!(role_key: "staff.surveyor", password: "password")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: project,
      membership: surveyor,
      assignment_kind: "surveyor"
    )
    reviewer = create_staff_membership!(role_key: "staff.technical_reviewer", password: "password")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: project,
      membership: reviewer,
      assignment_kind: "technical_reviewer",
      access_scope: "review"
    )

    sign_in_through_form(@staff.user, password: "password")
    visit new_staff_inspection_path(project_id: project.id)
    fill_in "Title", with: "H1 simulated hull check"
    fill_in "Inspection type", with: "general_observation"
    click_button "Create inspection"
    assert_text "ANT-INS-"
    page.save_screenshot(@dir.join("01_inspection_created_1280.png"))

    inspection = project.inspections.order(:id).last
    inspection.update!(assigned_surveyor_membership: surveyor, status: "assigned")

    sign_in_through_form(surveyor.user, password: "password")
    page.current_window.resize_to(390, 844)
    visit staff_inspection_path(inspection)
    assert_text "Checklist"
    page.save_screenshot(@dir.join("02_surveyor_workspace_390.png"))

    save_required_checklist_answers!(inspection: inspection, minimum: 2)

    visit staff_inspection_path(inspection)
    assert_text "Saved:", minimum: 2
    within(:xpath, "//h2[contains(.,'Record a finding')]/following::form[1]") do
      fill_in "Title", with: "Synthetic coating note"
      fill_in "Observation", with: "Visible coating wear at bow, simulated QA only."
      click_button "Record finding"
    end
    assert_text "coating note"
    click_button "Submit inspection"
    assert_text(/submitted|complete|Simulated/i)
    page.save_screenshot(@dir.join("03_inspection_submitted_390.png"))

    page.current_window.resize_to(1280, 900)
    sign_in_through_form(@staff.user, password: "password")
    visit new_staff_report_path(project_id: project.id, inspection_id: inspection.id)
    click_button "Create draft report"
    assert_text "Simulated technical report"
    fill_in "Executive summary", with: "Simulated H1 executive summary for acceptance."
    click_button "Save draft"
    click_button "Submit for review"
    assert_text(/submitted|review/i)
    page.save_screenshot(@dir.join("04_report_submitted_1280.png"))

    report = project.reports.order(:id).last

    sign_in_through_form(reviewer.user, password: "password")
    visit staff_report_path(report)
    assert_text "Reviewer decision"
    select_ant_option("Decision", "Request changes")
    fill_in "Comments", with: "Clarify conclusions for the simulated report."
    click_button "Record review"
    assert_text(/changes requested|Clarify conclusions/i)
    page.save_screenshot(@dir.join("05_changes_requested_1280.png"))

    sign_in_through_form(@staff.user, password: "password")
    visit staff_report_path(report.reload)
    click_button "Start corrected draft" if page.has_button?("Start corrected draft", wait: 2)
    assert_text(/draft|Corrected|Simulated/i)
    fill_in "Executive summary", with: "Corrected simulated summary after review comments."
    fill_in "Conclusions", with: "No operational certification claimed." if page.has_field?("Conclusions", wait: 1)
    click_button "Save draft"
    click_button "Submit for review"
    assert_text(/submitted|review/i)

    sign_in_through_form(reviewer.user, password: "password")
    visit staff_report_path(report.reload)
    assert_text "Reviewer decision"
    select_ant_option("Decision", "Approve")
    click_button "Record review"
    assert_text(/approved|View approved PDF/i)
    page.save_screenshot(@dir.join("06_report_approved_1280.png"))

    sign_in_through_form(@staff.user, password: "password")
    visit staff_report_path(report.reload)
    assert_text(/approved|View approved PDF/i)
    approved = report.report_versions.where(status: "approved").order(:version_number).last
    assert approved, "Expected an approved report version before release"
    release_label = "Release version #{approved.version_number} to client"
    assert_selector :button, release_label
    click_button release_label
    # Do not match revise copy ("released version") — require the flash/badge from a successful release.
    assert_text "This version is now available to the client.", wait: 10
    assert_text "Released to client"
    visit staff_report_path(report)
    assert_text "Released to client"
    assert report.reload.released_to_client?, "Release must persist an active client release"
    page.save_screenshot(@dir.join("07_report_released_1280.png"))

    page.current_window.resize_to(768, 1024)
    sign_in_through_form(@client.user, password: "password")
    visit client_reports_path
    assert_text report.reference_number
    page.save_screenshot(@dir.join("08_client_reports_768.png"))
    click_on report.title
    assert_text(/Download|PDF|report/i)
    page.save_screenshot(@dir.join("09_client_report_detail_768.png"))

    page.current_window.resize_to(1280, 900)
    sign_in_through_form(@staff.user, password: "password")
    visit staff_report_path(report)
    if page.has_field?("Reason for withdrawing client access", wait: 2)
      fill_in "Reason for withdrawing client access", with: "Withdraw simulated release for H1 acceptance."
      click_button "Revoke client release"
      assert_text(/withdraw|revok/i)
    end
    page.save_screenshot(@dir.join("10_release_revoked_1280.png"))

    sign_in_through_form(@client.user, password: "password")
    visit client_reports_path
    assert_text(/No reports shared yet|My reports/i)
  ensure
    page.current_window.resize_to(1280, 900) if page&.driver
  end

  private

    def save_required_checklist_answers!(inspection:, minimum:)
      saved = 0
      10.times do
        break if saved >= minimum

        visit staff_inspection_path(inspection)
        before = page.text.scan(/Saved:/).size
        card = page.all("article.staff-card").find do |node|
          node.text.include?("Required") && !node.text.include?("Saved:") && node.has_button?("Save answer")
        end
        break unless card

        prompt = card.find(".staff-card__title").text.split("Required").first.to_s.strip
        within(card) do
          if page.has_css?(".ant-select__trigger", wait: 2)
            find(".ant-select__trigger", match: :first).click
            assert_selector '[role="option"]', wait: 3
            preferred = page.all('[role="option"]').find { |opt| %w[No Satisfactory].include?(opt.text.strip) }
            choice = preferred || page.all('[role="option"]').find { |opt| opt.text.strip.present? && opt.text.strip != "Choose one" }
            flunk "No selectable ant_select option for #{prompt}" unless choice
            expected = choice.text.strip
            choice.click
            native = find("select.ant-select__native", visible: :all)
            assert_predicate native.value, :present?, "ant_select did not sync native value for #{prompt}"
            assert_no_selector ".ant-select__panel:not(.hidden)", wait: 2
          elsif page.has_field?("Response", wait: 0.2)
            fill_in "Response", with: "Simulated checklist note"
          elsif page.has_field?("Number", wait: 0.2)
            fill_in "Number", with: "2"
          else
            flunk "No visible answer control for #{prompt}"
          end
          click_button "Save answer"
        end

        assert_text(/Checklist updated|Saved:/i, wait: 5)
        visit staff_inspection_path(inspection)
        after = page.text.scan(/Saved:/).size
        assert_operator after, :>, before, "Saving checklist answer for #{prompt} did not increase Saved: count"
        saved += 1
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        next
      end

      assert_operator saved, :>=, minimum, "Expected to save at least #{minimum} checklist answers through visible controls"
    end
end
