# frozen_string_literal: true

module Inspections
  # Validates immutable checklist schema snapshots on template versions.
  module TemplateSchema
    RESPONSE_TYPES = %w[
      yes_no_na
      satisfactory_unsatisfactory
      short_text
      long_text
      numeric
      date
      single_select
      multi_select
    ].freeze

    Result = Struct.new(:valid, :errors, keyword_init: true) do
      def valid?
        valid
      end
    end

    module_function

    def validate(schema)
      errors = []
      unless schema.is_a?(Hash)
        return Result.new(valid: false, errors: [ "must be a JSON object" ])
      end

      sections = schema["sections"]
      if sections.blank?
        errors << "must include at least one section"
      elsif !sections.is_a?(Array)
        errors << "sections must be an array"
      else
        sections.each_with_index do |section, index|
          validate_section(section, index, errors)
        end
      end

      Result.new(valid: errors.empty?, errors: errors)
    end

    def validate_section(section, index, errors)
      unless section.is_a?(Hash)
        errors << "section #{index + 1} must be an object"
        return
      end

      errors << "section #{index + 1} requires a key" if section["key"].blank?
      errors << "section #{index + 1} requires a title" if section["title"].blank?

      items = section["items"]
      if items.blank?
        errors << "section #{index + 1} requires at least one item"
      elsif !items.is_a?(Array)
        errors << "section #{index + 1} items must be an array"
      else
        items.each_with_index do |item, item_index|
          validate_item(item, index, item_index, errors)
        end
      end
    end

    def validate_item(item, section_index, item_index, errors)
      label = "section #{section_index + 1} item #{item_index + 1}"
      unless item.is_a?(Hash)
        errors << "#{label} must be an object"
        return
      end

      errors << "#{label} requires a key" if item["key"].blank?
      errors << "#{label} requires a prompt" if item["prompt"].blank?

      response_type = item["response_type"]
      if response_type.blank?
        errors << "#{label} requires a response_type"
      elsif !RESPONSE_TYPES.include?(response_type)
        errors << "#{label} has an unsupported response_type"
      end

      if response_type.in?(%w[single_select multi_select]) && !item["options"].is_a?(Array)
        errors << "#{label} requires options for select response types"
      end
    end
  end
end
