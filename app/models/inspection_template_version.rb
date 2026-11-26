# frozen_string_literal: true

class InspectionTemplateVersion < ApplicationRecord
  self.record_timestamps = false

  belongs_to :inspection_template
  belongs_to :created_by_membership, class_name: "Membership"

  has_many :inspections, dependent: :restrict_with_exception

  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :version_number, uniqueness: { scope: :inspection_template_id }
  validates :schema_json, presence: true
  validate :schema_structure

  def label
    "Version #{version_number}"
  end

  def published?
    published_at.present?
  end

  private

    def schema_structure
      result = Inspections::TemplateSchema.validate(schema_json)
      result.errors.each { |msg| errors.add(:schema_json, msg) } unless result.valid?
    end
end
