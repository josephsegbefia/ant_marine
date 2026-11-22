require "test_helper"

class WorkspaceSelectionPageTest < ActionDispatch::IntegrationTest
  test "workspace selector matches A06 structure when authenticated" do
    sign_in_as(users(:dual_domain))

    get workspace_selection_path
    assert_response :success
    assert_select ".login-page"
    assert_select "h2", text: "Choose your company."
    assert_select ".workspace-list .workspace-item", minimum: 2
    assert_select ".login-form__hint", text: /authorised to use/
  end
end
