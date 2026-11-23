# frozen_string_literal: true

module HasPublicRichText
  extend ActiveSupport::Concern

  included do
    class_attribute :public_rich_text_attributes, instance_writer: false, default: []
    before_validation :enforce_public_rich_text_attachment_policy
  end

  class_methods do
    def has_public_rich_text(*attributes)
      symbols = attributes.map(&:to_sym)
      self.public_rich_text_attributes = (public_rich_text_attributes + symbols).uniq
      # Legacy text columns were removed; never persist these names on the base table.
      self.ignored_columns = (ignored_columns + symbols.map(&:to_s)).uniq
      symbols.each { |name| has_rich_text name }
    end
  end

  def rich_text_blank?(name)
    rich_text = public_send(name)
    rich_text.blank? || rich_text.to_plain_text.strip.blank?
  end

  def rich_text_present?(name)
    !rich_text_blank?(name)
  end

  private

    def enforce_public_rich_text_attachment_policy
      self.class.public_rich_text_attributes.each do |attr|
        rich_text = public_send(attr)
        next if rich_text.blank?

        body = rich_text.body.to_s
        next unless PublicContent::RichText.attachments_present?(body)

        errors.add(attr, "Images and file attachments are not supported yet.")
        PublicContent::RichText.scrub!(rich_text)
      end
    end
end
