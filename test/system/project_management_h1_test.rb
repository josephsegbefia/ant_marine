# frozen_string_literal: true

require "application_system_test_case"

class ProjectManagementH1Test < ApplicationSystemTestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @owner = memberships(:client_owner_membership)
    pack = build_accepted_project!(staff: @staff, owner: @owner, idempotency_key: "f405-h1-system")
    @project = pack[:project]
  end

  test "staff opens simulated project workspace" do
    sign_in_through_form(@staff.user, password: "password")
    visit staff_project_path(@project)
    assert_text @project.reference_number
    assert_text(/Simulated/i)
    assert_text(/Agreed commercial terms|Project overview|Job details/i)
  end

  test "client sees own project without internal notes" do
    @project.update!(internal_notes: "SYSTEM SECRET NOTE")
    sign_in_through_form(@owner.user, password: "password")
    visit client_project_path(@project)
    assert_text @project.reference_number
    assert_text(/Simulated/i)
    assert_no_text "SYSTEM SECRET NOTE"
  end
end
