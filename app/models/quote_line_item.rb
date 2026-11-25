# frozen_string_literal: true

class QuoteLineItem < ApplicationRecord
  QUANTITY_PATTERN = /\A\d+(\.\d+)?\z/
  MAX_QUANTITY = BigDecimal("1000000")
  COMMON_UNITS = {
    "each" => "Each",
    "hour" => "Hour",
    "day" => "Day",
    "visit" => "Visit",
    "survey" => "Survey",
    "report" => "Report",
    "lot" => "Lot"
  }.freeze
  OTHER_UNIT = "other"
  CUSTOM_UNIT_MAX = 30
  CUSTOM_UNIT_PATTERN = %r{\A[\p{L}\p{N}][\p{L}\p{N} .,/()²³%-]*\z}

  belongs_to :quote_revision, inverse_of: :line_items

  validates :description, length: { maximum: 500 }
  validates :unit, presence: { message: "Choose a unit, or choose Other and type one." }, length: { maximum: CUSTOM_UNIT_MAX }
  validate :custom_unit_format, if: :unit_changed?
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :quantity_format
  validate :unit_price_input
  validate :revision_must_be_editable

  before_validation :normalize_description
  before_validation :recalculate_line_total
  before_destroy :prevent_destroy_when_revision_frozen, prepend: true

  def unit_price=(value)
    @unit_price_input = value.to_s
    @unit_price_error = nil
    self.unit_price_cents = @unit_price_input.strip.empty? ? 0 : Commercial::Money.parse_minor(@unit_price_input, currency)
  rescue Commercial::Money::ParseError => e
    @unit_price_error = e.message
    unit_price_cents_will_change!
  end

  def quantity=(value)
    super
    quantity_will_change! if value.is_a?(String) && !value.strip.match?(QUANTITY_PATTERN)
  end

  def unit_choice=(value)
    @unit_choice = value.to_s
    apply_unit_choice
  end

  def unit_other=(value)
    @unit_other = value.to_s
    apply_unit_choice
  end

  # Values outside the common list (including older free-text units) appear as Other
  # with the stored text kept exactly as it was.
  def unit_choice
    return @unit_choice if @unit_choice.present?
    return "each" if unit.blank?

    COMMON_UNITS.key?(unit) ? unit : OTHER_UNIT
  end

  def unit_other
    return @unit_other if @unit_other
    return "" if COMMON_UNITS.key?(unit.to_s)

    unit.to_s
  end

  def unit_price
    return @unit_price_input if @unit_price_input
    return "" if new_record? && unit_price_cents.to_i.zero?

    Commercial::Money.to_input(unit_price_cents, currency)
  end

  def quantity_input
    raw = quantity_before_type_cast
    return raw.to_s if raw.is_a?(String)

    quantity.present? ? BigDecimal(quantity.to_s).to_s("F").sub(/\.0\z/, "") : "1"
  end

  def currency
    quote_revision&.currency.presence || "GHS"
  end

  private

    def apply_unit_choice
      return if @unit_choice.blank?

      if COMMON_UNITS.key?(@unit_choice)
        self.unit = @unit_choice
      elsif @unit_choice == OTHER_UNIT
        custom = @unit_other.to_s.squish
        stored = unit_in_database.to_s
        self.unit =
          if stored.present? && custom == stored.squish
            stored
          elsif COMMON_UNITS.key?(custom.downcase)
            custom.downcase
          else
            custom
          end
      else
        self.unit = ""
      end
    end

    def custom_unit_format
      return if unit.blank? || COMMON_UNITS.key?(unit)

      if unit.casecmp?(OTHER_UNIT)
        errors.add(:unit, "Type the unit you need instead of “Other”.")
      elsif !unit.match?(CUSTOM_UNIT_PATTERN)
        errors.add(:unit, "Use letters, numbers, spaces or . , / ( ) % - in the unit.")
      end
    end

    def normalize_description
      self.description = description.to_s.strip
    end

    def quantity_format
      raw = quantity_before_type_cast
      text = raw.is_a?(String) ? raw.strip : raw.to_s

      unless text.match?(QUANTITY_PATTERN) || raw.is_a?(Numeric)
        errors.add(:quantity, "Enter a quantity as a number, for example 2 or 1.5.")
        return
      end
      if text.include?(".") && text.split(".", 2).last.sub(/0+\z/, "").length > 3
        errors.add(:quantity, "Use no more than 3 decimal places for the quantity.")
        return
      end

      value = BigDecimal(text)
      errors.add(:quantity, "Quantity must be greater than zero.") unless value.positive?
      errors.add(:quantity, "Quantity is too large. The maximum is 1,000,000.") if value > MAX_QUANTITY
    rescue ArgumentError
      errors.add(:quantity, "Enter a quantity as a number, for example 2 or 1.5.")
    end

    def unit_price_input
      errors.add(:unit_price, @unit_price_error) if @unit_price_error
    end

    def revision_must_be_editable
      return unless revision_frozen_in_database?

      errors.add(:base, QuoteRevision::FROZEN_MESSAGE)
    end

    def prevent_destroy_when_revision_frozen
      return unless revision_frozen_in_database?

      errors.add(:base, QuoteRevision::FROZEN_MESSAGE)
      throw :abort
    end

    def revision_frozen_in_database?
      revision_id = quote_revision_id_in_database || quote_revision_id
      return false if revision_id.blank?

      QuoteRevision.where(id: revision_id).where.not(frozen_at: nil).exists?
    end

    def recalculate_line_total
      qty = BigDecimal(quantity.to_s.presence || "0")
      self.line_total_cents = (qty * unit_price_cents.to_i).round
    rescue ArgumentError
      self.line_total_cents = 0
    end
end
