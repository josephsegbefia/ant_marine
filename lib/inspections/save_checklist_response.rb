# frozen_string_literal: true

module Inspections
  class SaveChecklistResponse
    Result = Data.define(:response)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end
    class StaleState < Error; end

    def self.call(membership:, inspection:, item_key:, response_type:, value_json:, not_applicable_reason: nil, lock_version: nil)
      new(membership: membership).call(
        inspection: inspection,
        item_key: item_key,
        response_type: response_type,
        value_json: value_json,
        not_applicable_reason: not_applicable_reason,
        lock_version: lock_version
      )
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(inspection:, item_key:, response_type:, value_json:, not_applicable_reason:, lock_version:)
      raise Denied, "You are not allowed to edit this checklist." unless Inspections::Access.can_edit_checklist?(@membership, inspection)

      item = Inspections::Checklist.item_for(inspection.inspection_template_version, item_key)
      raise InvalidState, "That checklist item does not exist on this template." unless item
      raise InvalidState, "Response type does not match the template." unless item["response_type"] == response_type.to_s

      normalized = normalize_value!(item, value_json, not_applicable_reason)

      Inspection.transaction do
        locked = Inspection.lock.find(inspection.id)
        raise InvalidState, "This inspection no longer accepts checklist changes." unless locked.editable_checklist?

        response = locked.inspection_checklist_responses.find_or_initialize_by(item_key: item_key.to_s)
        if response.persisted? && lock_version.present? && response.lock_version != lock_version.to_i
          raise StaleState, "Someone else updated this answer. Refresh and try again."
        end

        response.assign_attributes(
          response_type: response_type.to_s,
          value_json: normalized[:value_json],
          not_applicable_reason: normalized[:not_applicable_reason],
          updated_by_membership: @membership
        )
        response.save!
        Inspections::Audit.checklist_saved(inspection: locked, response: response, actor_membership: @membership)
        Result.new(response: response)
      end
    end

    private

      def normalize_value!(item, value_json, not_applicable_reason)
        payload = value_json.is_a?(Hash) ? value_json.stringify_keys : {}
        type = item["response_type"]
        case type
        when "yes_no_na"
          answer = payload["answer"].to_s
          raise InvalidState, "Choose yes, no, or not applicable." unless answer.in?(%w[yes no na])
          if answer == "na" && not_applicable_reason.to_s.strip.blank?
            raise InvalidState, "Explain why this item is not applicable."
          end
          { value_json: { "answer" => answer }, not_applicable_reason: (answer == "na" ? not_applicable_reason.to_s.strip : nil) }
        when "satisfactory_unsatisfactory"
          answer = payload["answer"].to_s
          raise InvalidState, "Choose satisfactory or unsatisfactory." unless answer.in?(%w[satisfactory unsatisfactory])
          { value_json: { "answer" => answer }, not_applicable_reason: nil }
        when "short_text", "long_text"
          text = payload["text"].to_s.strip
          raise InvalidState, "Enter a response." if item["required"] && text.blank?
          { value_json: { "text" => text }, not_applicable_reason: nil }
        when "numeric"
          raw = payload["number"]
          raise InvalidState, "Enter a number." if item["required"] && raw.to_s.strip.blank?
          { value_json: { "number" => raw }, not_applicable_reason: nil }
        when "date"
          date = payload["date"].to_s.strip
          raise InvalidState, "Enter a date." if item["required"] && date.blank?
          { value_json: { "date" => date }, not_applicable_reason: nil }
        when "single_select"
          selected = payload["selected"].to_s.strip
          raise InvalidState, "Choose an option." if item["required"] && selected.blank?
          allowed = Array(item["options"]).map { |opt| opt["value"] }
          raise InvalidState, "That option is not allowed." if selected.present? && !allowed.include?(selected)
          { value_json: { "selected" => selected }, not_applicable_reason: nil }
        when "multi_select"
          selected = Array(payload["selected"]).map(&:to_s).reject(&:blank?)
          raise InvalidState, "Choose at least one option." if item["required"] && selected.empty?
          allowed = Array(item["options"]).map { |opt| opt["value"] }
          raise InvalidState, "One or more options are not allowed." unless selected.all? { |val| allowed.include?(val) }
          { value_json: { "selected" => selected }, not_applicable_reason: nil }
        else
          raise InvalidState, "Unsupported response type."
        end
      end
  end
end
