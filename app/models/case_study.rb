# frozen_string_literal: true

class CaseStudy < ApplicationRecord
  include PublicContentEditorial
  include HasPublicRichText

  has_public_rich_text :body, :client_challenge, :approach, :work_performed, :outcome

  validate :case_study_story_fields, on: :editorial

  def self.find_published_by_slug!(slug)
    published_catalogue.for_ant_marine.find_by!(slug: slug)
  end

  private

    def case_study_story_fields
      errors.add(:client_challenge, "Describe the client's situation.") if rich_text_blank?(:client_challenge)
      errors.add(:approach, "Describe ANT Marine's approach.") if rich_text_blank?(:approach)
    end
end
