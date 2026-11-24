# frozen_string_literal: true

class Service < ApplicationRecord
  include PublicContentPublishable
  include HasPublicRichText

  has_public_rich_text :body

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  scope :ordered, -> { order(:published_display_order, :display_order, :title) }
  scope :published_catalogue, -> { where(status: "published") }
  scope :for_ant_marine, -> { joins(:organization).where(organizations: { kind: "ant_marine" }) }

  validates :title, presence: { message: "Enter a service name." }, on: %i[create update]
  validates :slug, presence: true, format: { with: SLUG_FORMAT, message: "could not be generated — check the service name" },
                   uniqueness: { scope: :organization_id }
  validate :editorial_requirements, on: :editorial

  before_validation :normalize_list_columns
  before_validation :assign_slug_from_title, on: :create
  before_validation :prevent_slug_changes, on: :update

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
    return published_body if published_body.present?

    PublicContent::RichText.snapshot_html(body)
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

  def public_page_path
    slug.present? ? "/services/#{slug}" : nil
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

  private

    def normalize_list_columns
      self.scope_items = coerce_string_list(scope_items)
      self.process_steps = coerce_string_list(process_steps)

      if new_record?
        self.published_scope_items = coerce_string_list(published_scope_items)
        self.published_process_steps = coerce_string_list(published_process_steps)
        self.seo = seo.presence || {}
        self.published_seo = published_seo.presence || {}
      end
    end

    def coerce_string_list(value)
      case value
      when Array
        value.map { |item| item.to_s.strip }.reject(&:blank?)
      when String
        stripped = value.strip
        return JSON.parse(stripped).map(&:to_s).reject(&:blank?) if stripped.start_with?("[")

        return value.lines.map(&:strip).reject(&:blank?) if value.include?("\n")

        []
      when nil
        []
      else
        []
      end
    rescue JSON::ParserError
      []
    end

    def assign_slug_from_title
      return if organization.blank?
      return if title.blank?

      self.slug = PublicContent::ServiceSlug.generate(
        title: title,
        organization: organization,
        except_id: id
      )
    end

    def prevent_slug_changes
      return if new_record?
      return unless slug_changed?

      self.slug = slug_in_database if slug_in_database.present?
    end

    def editorial_requirements
      errors.add(:summary, "Add a short description.") if summary.blank?
      errors.add(:body, "Describe what this service involves.") if rich_text_blank?(:body)
      errors.add(:audience, "Tell us who this service is for.") if audience.blank?
      errors.add(:category, "Choose a service category.") if category.blank?
      if icon_key.present? && !PublicContent::IconCatalog.valid?(icon_key)
        errors.add(:icon_key, "Choose a recognised icon.")
      end
    end
end
