# frozen_string_literal: true

module Inspections
  module Checklist
    module_function

    def items(version)
      schema = version.schema_json
      return [] unless schema.is_a?(Hash)

      Array(schema["sections"]).flat_map { |section| Array(section["items"]) }
    end

    def item_for(version, item_key)
      items(version).find { |item| item["key"] == item_key.to_s }
    end

    def required_keys(version)
      items(version).select { |item| item["required"] }.map { |item| item["key"] }
    end

    def evidence_required_keys(version)
      items(version).select { |item| item["evidence_required"] }.map { |item| item["key"] }
    end

    def response_complete?(item, response)
      return false unless response

      type = item["response_type"]
      value = response.value_json
      case type
      when "yes_no_na"
        answer = value["answer"].to_s
        return true if answer.in?(%w[yes no])
        answer == "na" && response.not_applicable_reason.to_s.strip.present?
      when "satisfactory_unsatisfactory"
        value["answer"].to_s.in?(%w[satisfactory unsatisfactory])
      when "short_text", "long_text"
        value["text"].to_s.strip.present?
      when "numeric"
        !value["number"].nil? && value["number"].to_s.strip.present?
      when "date"
        value["date"].to_s.strip.present?
      when "single_select"
        value["selected"].to_s.strip.present?
      when "multi_select"
        Array(value["selected"]).any?(&:present?)
      else
        false
      end
    end
  end
end
