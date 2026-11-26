# frozen_string_literal: true

require "test_helper"

class Inspections::TemplateSchemaTest < ActiveSupport::TestCase
  test "valid qa payload passes" do
    result = Inspections::TemplateSchema.validate(Inspections::QaTemplateSeeder.schema_payload)
    assert result.valid?, result.errors.join(", ")
  end

  test "rejects unknown response type" do
    payload = {
      "sections" => [
        {
          "key" => "s1",
          "title" => "Section",
          "items" => [
            { "key" => "i1", "prompt" => "Q?", "response_type" => "invalid_type" }
          ]
        }
      ]
    }
    result = Inspections::TemplateSchema.validate(payload)
    assert_not result.valid?
    assert result.errors.any? { |e| e.include?("unsupported response_type") }
  end
end
