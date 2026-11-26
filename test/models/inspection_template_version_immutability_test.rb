# frozen_string_literal: true

require "test_helper"

class InspectionTemplateVersionImmutabilityTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @template = seed_qa_template!(staff: @staff)
    @version = @template.current_version
  end

  test "sql update of schema_json is rejected" do
    assert_raises(ActiveRecord::StatementInvalid) do
      @version.update_columns(schema_json: { "tampered" => true })
    end
  end

  test "sql delete of template version is rejected" do
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "DELETE FROM inspection_template_versions WHERE id = #{@version.id}"
      )
    end
  end
end
