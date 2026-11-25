# frozen_string_literal: true

require "test_helper"

class Staff::ClientContactsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ops_manager), membership: memberships(:ops_manager_membership))
    @client = organizations(:acme_client)
  end

  test "staff can add a business contact without creating a portal user" do
    assert_difference -> { ClientContact.count }, 1 do
      assert_no_difference -> { User.count } do
        post create_contact_staff_client_path(@client), params: {
          client_contact: {
            full_name: "Harbour Desk",
            email: "desk-#{SecureRandom.hex(3)}@harbour.test",
            phone: "+233 20 555 0101",
            job_title: "Operations desk"
          }
        }
      end
    end
    assert_redirected_to staff_client_path(@client, tab: "access")
    follow_redirect!
    assert_includes response.body, "Harbour Desk"
    assert_includes response.body, "Business contacts"
  end
end
