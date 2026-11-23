# frozen_string_literal: true

class Article < ApplicationRecord
  include PublicContentEditorial
  include HasPublicRichText

  has_public_rich_text :body

  CATEGORIES = {
    "guidance" => "Practical guidance",
    "news" => "News and updates",
    "company" => "Company perspectives"
  }.freeze

  validates :category, inclusion: { in: CATEGORIES.keys }, allow_blank: true, on: :editorial

  def self.find_published_by_slug!(slug)
    published_catalogue.for_ant_marine.find_by!(slug: slug)
  end

  def public_category
    CATEGORIES[published_category.presence || category] || (published_category.presence || category).to_s.humanize
  end
end
