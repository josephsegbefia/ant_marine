# frozen_string_literal: true

module PublicContentPublishable
  extend ActiveSupport::Concern

  STATUSES = %w[draft in_review approved published archived].freeze

  included do
    belongs_to :organization
    belongs_to :created_by_membership, class_name: "Membership", optional: true
    belongs_to :updated_by_membership, class_name: "Membership", optional: true
    belongs_to :approved_by_membership, class_name: "Membership", optional: true
    belongs_to :published_by_membership, class_name: "Membership", optional: true

    validates :status, inclusion: { in: STATUSES }
    validates :seo, exclusion: { in: [ nil ] }
    validates :published_seo, exclusion: { in: [ nil ] }
  end

  def draft?
    status == "draft"
  end

  def in_review?
    status == "in_review"
  end

  def approved?
    status == "approved"
  end

  def published?
    status == "published"
  end

  def archived?
    status == "archived"
  end

  def publicly_visible?
    published?
  end
end
