# frozen_string_literal: true

module PublicContentEditorial
  extend ActiveSupport::Concern

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  included do
    include PublicContentPublishable

    scope :published_catalogue, -> { where(status: "published") }
    scope :for_ant_marine, -> { joins(:organization).where(organizations: { kind: "ant_marine" }) }
    scope :ordered, -> { order(published_at: :desc, updated_at: :desc, title: :asc) }

    validates :title, presence: { message: "Enter a title." }, on: %i[create update]
    validates :slug, presence: true, format: { with: SLUG_FORMAT, message: "could not be generated — check the title" },
                     uniqueness: { scope: :organization_id }

    before_validation :assign_slug_from_title, on: :create
    before_validation :prevent_slug_changes, on: :update
    before_validation :normalize_seo_defaults

    validate :editorial_requirements, on: :editorial
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

  def public_seo_title
    (published_seo["title"].presence || seo["title"].presence || public_title).to_s
  end

  def public_seo_description
    (published_seo["description"].presence || seo["description"].presence || public_summary).to_s
  end

  private

    def assign_slug_from_title
      return if organization.blank? || title.blank?

      self.slug = PublicContent::ContentSlug.generate(
        title: title,
        scope: self.class.where(organization_id: organization_id),
        except_id: id
      )
    end

    def prevent_slug_changes
      return if new_record? || !slug_changed?

      self.slug = slug_in_database if slug_in_database.present?
    end

    def normalize_seo_defaults
      self.seo = seo.presence || {}
      self.published_seo = published_seo.presence || {} if new_record?
    end

    def editorial_requirements
      errors.add(:summary, "Add a short introduction.") if summary.blank?
      errors.add(:body, "Add the main content.") if rich_text_blank?(:body)
    end
end
