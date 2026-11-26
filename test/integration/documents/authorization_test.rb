# frozen_string_literal: true

require "test_helper"

class Documents::AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @staff = memberships(:ops_manager_membership)
    @client = memberships(:client_owner_membership)
    @project = build_accepted_project!(staff: @staff, owner: @client)[:project]
    @stranger_staff = create_staff_membership!(role_key: "staff.surveyor")
  end

  test "unassigned staff denied and active storage blob route is not mounted" do
    sign_in_as(@staff.user, membership: @staff)
    file = Rack::Test::UploadedFile.new(StringIO.new("secret"), "text/plain", original_filename: "x.txt")
    post staff_project_documents_path(@project), params: {
      document: { title: "Scoped", category: "other", classification: "standard", visibility_intent: "internal", file: file }
    }
    document = Document.order(:id).last
    perform_enqueued_jobs only: ScanStorageAssetJob

    sign_in_as(@stranger_staff.user, membership: @stranger_staff)
    get staff_project_document_path(@project, document)
    assert_response :not_found

    get "/rails/active_storage/blobs/redirect/00000000-0000-0000-0000-000000000000"
    assert_response :not_found
  end

  test "collaborator cannot approve document" do
    sign_in_as(@staff.user, membership: @staff)
    file = Rack::Test::UploadedFile.new(StringIO.new("evidence"), "text/plain", original_filename: "evidence.txt")
    post staff_project_documents_path(@project), params: {
      document: {
        title: "Technical pack",
        category: "technical_evidence",
        classification: "standard",
        visibility_intent: "internal",
        file: file
      }
    }
    document = Document.order(:id).last
    perform_enqueued_jobs only: ScanStorageAssetJob
    Documents::SubmitForReview.call(membership: @staff, document: document)
    version = document.current_version

    collaborator = create_staff_membership!(role_key: "staff.surveyor")
    Delivery::Assign.call(
      actor_membership: @staff,
      project: @project,
      membership: collaborator,
      assignment_kind: "collaborator",
      access_scope: "collaborator"
    )

    sign_in_as(collaborator.user, membership: collaborator)
    assert_raises(Documents::Review::Denied) do
      Documents::Review.call(
        membership: collaborator,
        document: document.reload,
        version: version,
        outcome: "approved"
      )
    end
  end

  test "cross client cannot view document" do
    sign_in_as(@staff.user, membership: @staff)
    file = Rack::Test::UploadedFile.new(StringIO.new("client"), "text/plain", original_filename: "c.txt")
    post staff_project_documents_path(@project), params: {
      document: {
        title: "Shared",
        category: "other",
        classification: "standard",
        visibility_intent: "for_client_release",
        file: file
      }
    }
    document = Document.order(:id).last
    perform_enqueued_jobs only: ScanStorageAssetJob
    Documents::Release.call(membership: @staff, document: document, version: document.current_version, confirmation: true)

    foreign_org = organizations(:other_client)
    other_client = Membership.create!(
      user: User.create!(
        email: "other-client-#{SecureRandom.hex(3)}@example.com",
        password: "Secure-password-123",
        password_confirmation: "Secure-password-123",
        status: "active"
      ),
      organization: foreign_org,
      role_key: "client.client_member",
      status: "active",
      permission_epoch: 0,
      lock_version: 0,
      accepted_at: Time.current
    )

    sign_in_as(other_client.user, membership: other_client)
    get client_project_path(@project)
    assert_response :not_found
    get client_project_document_path(@project, document)
    assert_response :not_found
  end
end
