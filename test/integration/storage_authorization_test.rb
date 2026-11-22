# frozen_string_literal: true

require "test_helper"

class StorageAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @asset = upload_storage_proof!(
      membership: memberships(:super_admin_membership),
      bytes: "Hello PoC storage proof."
    )
  end

  test "anonymous download is denied" do
    get staff_storage_proof_download_path(@asset)

    assert_response :redirect
  end

  test "authorized staff download succeeds" do
    sign_in_as users(:super_admin), membership: memberships(:super_admin_membership)
    get staff_storage_proof_download_path(@asset)

    assert_response :success
    assert_includes response.body, "Hello PoC"
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "cross organization staff download is denied" do
    other_client = memberships(:client_membership)
    sign_in_as other_client.user, membership: other_client

    get staff_storage_proof_download_path(@asset)

    assert_redirected_to root_path
  end

  test "confidential file requires extra permission" do
    confidential = upload_storage_proof!(
      membership: memberships(:super_admin_membership),
      bytes: "Confidential bytes",
      classification: "confidential"
    )
    sign_in_as users(:staff_only), membership: memberships(:staff_membership)

    get staff_storage_proof_download_path(confidential)

    assert_redirected_to root_path
  end

  test "active storage routes are not mounted" do
    get "/rails/active_storage/blobs/redirect/invalid"

    assert_response :not_found
  end
end
