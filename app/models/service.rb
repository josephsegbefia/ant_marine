# frozen_string_literal: true

class Service < ApplicationRecord
  include PublicContentPublishable

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  scope :ordered, -> { order(:published_display_order, :display_order, :title) }
  scope :published_catalogue, -> { where(status: "published") }
  scope :for_ant_marine, -> { joins(:organization).where(organizations: { kind: "ant_marine" }) }

  validates :slug, presence: true, format: { with: SLUG_FORMAT }
  validates :title, presence: true
  validates :slug, uniqueness: { scope: :organization_id }
  validates :scope_items, :process_steps, exclusion: { in: [ nil ] }
  validates :published_scope_items, :published_process_steps, exclusion: { in: [ nil ] }

  def self.find_published_by_slug!(slug)
    published_catalogue.for_ant_marine.find_by!(slug: slug)
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

  def public_audience
    published_audience.presence || audience
  end

  def public_scope_items
    json_array(published_scope_items.presence || scope_items)
  end

  def public_process_steps
    json_array(published_process_steps.presence || process_steps)
  end

  def json_array(value)
    return value if value.is_a?(Array)
    return JSON.parse(value) if value.is_a?(String) && value.start_with?("[")

    []
  rescue JSON::ParserError
    []
  end

  def public_seo_title
    (published_seo["title"].presence || seo["title"].presence || public_title).to_s
  end

  def public_seo_description
    (published_seo["description"].presence || seo["description"].presence || public_summary).to_s
  end
end
