# frozen_string_literal: true

require "application_system_test_case"

class ClientShellNavigationTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(390, 844)
    @user = users(:client_owner)
    @membership = memberships(:client_owner_membership)
  end

  teardown do
    page.driver.browser.manage.window.resize_to(1280, 900)
  rescue StandardError
    nil
  end

  test "closed mobile drawer does not intercept quotation decision links" do
    quote = approve_quote!(create_ready_quote)
    quote.update_columns(client_organization_id: @membership.organization_id)
    release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: memberships(:ops_manager_membership),
      quote: quote,
      quote_revision: quote.current_revision,
      client_organization: @membership.organization
    ).release

    sign_in_through_form(@user, password: "password")
    visit client_quotation_path(release)
    assert_selector "h1", text: /Review quotation/

    # Drawer starts closed; Accept must be clickable without opening Menu first.
    click_link "Accept quotation"
    assert_selector "h1", text: /Accept this quotation/
    assert_current_path decide_client_quotation_path(release, type: "accepted")

    click_link "Cancel"
    assert_selector "h1", text: /Review quotation/

    find("button.client-mobile-nav-toggle", text: /Menu/).click
    assert_selector ".client-app-side__nav--open"
    page.send_keys(:escape)
    assert_no_selector ".client-app-side__nav--open"

    click_link "Accept quotation"
    assert_selector "h1", text: /Accept this quotation/
  end
end
