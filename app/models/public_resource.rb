# frozen_string_literal: true

class PublicResource < ApplicationRecord
  include PublicContentEditorial
  include HasPublicRichText

  has_public_rich_text :body

  RESOURCE_CATEGORIES = {
    "guide" => "Technical guide",
    "publication" => "Publication",
    "reference" => "Reference material"
  }.freeze

  validates :resource_category, inclusion: { in: RESOURCE_CATEGORIES.keys }, allow_blank: true, on: :editorial

  def self.find_published_by_slug!(slug)
    published_catalogue.for_ant_marine.find_by!(slug: slug)
  end

  def public_resource_category
    RESOURCE_CATEGORIES[published_resource_category.presence || resource_category] ||
      (published_resource_category.presence || resource_category).to_s.humanize
  end

  def public_file_release_enabled?
    published_file_release_enabled
  end

  def downloadable?
    published? && public_file_release_enabled?
  end
end
