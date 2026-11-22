require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "kinds distinguish ant marine and client" do
    assert organizations(:ant_marine).ant_marine?
    assert organizations(:acme_client).client?
  end

  test "cannot create second active ant marine organisation" do
    duplicate = Organization.new(kind: "ant_marine", name: "Duplicate", slug: "duplicate", status: "active")
    assert_not duplicate.valid?
  end
end
