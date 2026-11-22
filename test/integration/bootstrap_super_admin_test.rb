require "test_helper"

class BootstrapSuperAdminTest < ActiveSupport::TestCase
  test "bootstrap is idempotent and does not repromote users" do
    email = "bootstrap-#{SecureRandom.hex(4)}@example.com"
    ENV["ANT_MARINE_BOOTSTRAP_EMAIL"] = email
    ENV["ANT_MARINE_BOOTSTRAP_PASSWORD"] = "bootstrap-password-12"

    assert_difference -> { User.count }, 1 do
      Rails.application.load_tasks
      Rake::Task["ant_marine:bootstrap_super_admin"].reenable
      Rake::Task["ant_marine:bootstrap_super_admin"].invoke
    end

    user = User.find_by!(email: email)
    membership = Membership.find_by!(user: user, organization: Organization.ant_marine!)
    assert_equal "staff.super_administrator", membership.role_key

    assert_no_difference -> { User.count } do
      Rake::Task["ant_marine:bootstrap_super_admin"].reenable
      Rake::Task["ant_marine:bootstrap_super_admin"].invoke
    end
  ensure
    ENV.delete("ANT_MARINE_BOOTSTRAP_EMAIL")
    ENV.delete("ANT_MARINE_BOOTSTRAP_PASSWORD")
  end
end
