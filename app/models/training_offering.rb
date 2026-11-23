# frozen_string_literal: true

class TrainingOffering < ApplicationRecord
  include PublicContentEditorial
  include HasPublicRichText

  has_public_rich_text :body

  before_validation :normalize_list_columns

  validate :training_audience_present, on: :editorial

  def self.find_published_by_slug!(slug)
    published_catalogue.for_ant_marine.find_by!(slug: slug)
  end

  def public_learning_objectives
    json_array(published_learning_objectives.presence || learning_objectives)
  end

  def public_topics
    json_array(published_topics.presence || topics)
  end

  def public_audience
    published_audience.presence || audience
  end

  def public_delivery_format
    published_delivery_format.presence || delivery_format
  end

  private

    def normalize_list_columns
      self.learning_objectives = coerce_string_list(learning_objectives)
      self.topics = coerce_string_list(topics)
      if new_record?
        self.published_learning_objectives = coerce_string_list(published_learning_objectives)
        self.published_topics = coerce_string_list(published_topics)
      end
    end

    def coerce_string_list(value)
      case value
      when Array then value.map(&:to_s).map(&:strip).reject(&:blank?)
      when String
        return JSON.parse(value).map(&:to_s).reject(&:blank?) if value.strip.start_with?("[")

        value.lines.map(&:strip).reject(&:blank?)
      else []
      end
    rescue JSON::ParserError
      []
    end

    def json_array(value)
      return value if value.is_a?(Array)

      []
    end

    def training_audience_present
      errors.add(:audience, "Say who this training is for.") if audience.blank?
    end
end
