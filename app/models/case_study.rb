# frozen_string_literal: true

class CaseStudy < ApplicationRecord
  include PublicContentEditorial

  validate :case_study_story_fields, on: :editorial

  def self.find_published_by_slug!(slug)
    published_catalogue.for_ant_marine.find_by!(slug: slug)
  end

  private

    def case_study_story_fields
      errors.add(:client_challenge, "Describe the client's situation.") if client_challenge.blank?
      errors.add(:approach, "Describe ANT Marine's approach.") if approach.blank?
    end
end
