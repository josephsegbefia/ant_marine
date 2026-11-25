# frozen_string_literal: true

# Internal staff note on an enquiry. Plain text, never shown to clients or on quotations.
# Notes are append-only: a correction is a new note that points at the note it corrects.
class ServiceInquiryNote < ApplicationRecord
  BODY_LIMIT = 4000

  belongs_to :service_inquiry
  belongs_to :author_membership, class_name: "Membership"
  belongs_to :corrects_note, class_name: "ServiceInquiryNote", optional: true
  has_one :correction, class_name: "ServiceInquiryNote", foreign_key: :corrects_note_id,
                       inverse_of: :corrects_note, dependent: :restrict_with_exception

  normalizes :body, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }

  validates :body, presence: { message: "Write the note before saving." },
                   length: { maximum: BODY_LIMIT, message: "Keep the note under #{BODY_LIMIT} characters." }
  validate :correction_belongs_to_same_enquiry

  def readonly?
    persisted?
  end

  def corrected?
    correction.present?
  end

  private

    def correction_belongs_to_same_enquiry
      return if corrects_note.nil? || corrects_note.service_inquiry_id == service_inquiry_id

      errors.add(:base, "A correction must belong to the same enquiry.")
    end
end
