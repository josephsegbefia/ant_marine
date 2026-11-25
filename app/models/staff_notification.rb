# frozen_string_literal: true

# In-app notice for one staff member, created from a recorded audit event. Never emailed.
class StaffNotification < ApplicationRecord
  KINDS = %w[
    new_enquiry enquiry_assigned enquiry_reassigned_away clarification_answered
    quote_accepted quote_declined quote_changes_requested
  ].freeze

  belongs_to :organization
  belongs_to :recipient_membership, class_name: "Membership"
  belongs_to :audit_event

  validates :kind, inclusion: { in: KINDS }

  scope :unread, -> { where(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def read?
    read_at.present?
  end

  def kind_label
    {
      "new_enquiry" => "New enquiry",
      "enquiry_assigned" => "Assigned to you",
      "enquiry_reassigned_away" => "Reassigned",
      "clarification_answered" => "Client answer recorded",
      "quote_accepted" => "Quotation accepted",
      "quote_declined" => "Quotation declined",
      "quote_changes_requested" => "Changes requested"
    }.fetch(kind)
  end

  def subject_record
    return @subject_record if defined?(@subject_record)

    @subject_record = case subject_type
    when "ServiceInquiry" then ServiceInquiry.find_by(id: subject_id)
    when "Quote" then Quote.find_by(id: subject_id)
    end
  end
end
