# frozen_string_literal: true

require "test_helper"

class Documents::AccessTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @project = build_accepted_project!(staff: @staff)[:project]
    @surveyor = create_staff_membership!(role_key: "staff.surveyor")
    @reviewer = create_staff_membership!(role_key: "staff.technical_reviewer")
    @finance = create_staff_membership!(role_key: "staff.finance_officer")
    @client = memberships(:client_owner_membership)
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: @surveyor,
      assignment_kind: "surveyor", access_scope: "delivery"
    )
    Delivery::Assign.call(
      actor_membership: @staff, project: @project, membership: @reviewer,
      assignment_kind: "technical_reviewer", access_scope: "review"
    )
  end

  test "ops manager can list and upload on project" do
    assert Documents::Access.can_list_project_documents?(@staff, @project)
    assert Documents::Access.can_upload?(@staff, @project)
    assert Documents::Access.can_request_upload?(@staff, @project)
  end

  test "delivery surveyor can upload but not request client files without catalogue" do
    assert Documents::Access.can_upload?(@surveyor, @project)
    assert_not Documents::Access.can_request_upload?(@surveyor, @project)
  end

  test "unassigned surveyor cannot list project documents" do
    stranger = create_staff_membership!(role_key: "staff.surveyor", email: "stranger-#{SecureRandom.hex(3)}@example.com")
    assert_not Documents::Access.can_list_project_documents?(stranger, @project)
    assert_not Documents::Access.can_upload?(stranger, @project)
  end

  test "reviewer can see review-eligible metadata only through view helper" do
    doc = sample_document!(actor: @staff, category: "technical_evidence")
    assert Documents::Access.can_view_metadata?(@reviewer, doc)
    assert Documents::Access.can_review?(@reviewer, doc)
    assert_not Documents::Access.can_upload?(@reviewer, @project)
  end

  test "finance cannot access documents without project permission" do
    assert_not Documents::Access.can_list_project_documents?(@finance, @project)
  end

  test "client can upload when catalogue allows" do
    assert Documents::Access.can_upload?(@client, @project)
    assert Documents::Access.can_list_project_documents?(@client, @project)
  end

  private

    def sample_document!(actor:, category: "field_notes")
      result = Documents::Upload.call(
        membership: actor,
        project: @project,
        filename: "notes.txt",
        io: StringIO.new("sample notes"),
        title: "Field sample",
        category: category
      )
      perform_enqueued_jobs only: ScanStorageAssetJob
      result.document.reload
    end
end
