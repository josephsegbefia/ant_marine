# frozen_string_literal: true

module InspectionsHelper
  def inspection_response_value(response)
    return nil unless response

    value = response.value_json
    case response.response_type
    when "yes_no_na", "satisfactory_unsatisfactory"
      value["answer"].to_s.humanize
    when "short_text", "long_text"
      value["text"]
    when "numeric"
      value["number"]
    when "date"
      value["date"]
    when "single_select"
      value["selected"]
    when "multi_select"
      Array(value["selected"]).join(", ")
    end
  end

  def checklist_sections(inspection)
    schema = inspection.inspection_template_version.schema_json
    return [] unless schema.is_a?(Hash)

    Array(schema["sections"])
  end
end
