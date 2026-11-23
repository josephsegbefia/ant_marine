# frozen_string_literal: true

class PublicSitePage < ApplicationRecord
  include PublicContentPublishable

  PAGE_KEYS = %w[homepage about industries how_we_work contact].freeze

  scope :published_pages, -> { where(status: "published") }
  scope :for_ant_marine, -> { joins(:organization).where(organizations: { kind: "ant_marine" }) }

  validates :page_key, inclusion: { in: PAGE_KEYS }
  validates :page_key, uniqueness: { scope: :organization_id }
  validates :title, presence: true
  validates :page_data, :published_page_data, exclusion: { in: [ nil ] }

  def self.find_published_by_key!(key)
    published_pages.for_ant_marine.find_by!(page_key: key)
  end

  def self.find_published_by_key(key)
    published_pages.for_ant_marine.find_by(page_key: key)
  end

  def public_title
    published_title.presence || title
  end

  def public_summary
    published_summary.presence || summary
  end

  def public_body
    published_body.presence || body
  end

  def public_page_data
    published_page_data.presence || page_data
  end

  def public_seo_title
    (published_seo["title"].presence || seo["title"].presence || public_title).to_s
  end

  def public_seo_description
    (published_seo["description"].presence || seo["description"].presence || public_summary).to_s
  end
end
