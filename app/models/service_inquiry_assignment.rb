# frozen_string_literal: true

# One change of responsibility for an enquiry. History rows are never edited or deleted.
class ServiceInquiryAssignment < ApplicationRecord
  REASON_LIMIT = 500

  belongs_to :service_inquiry
  belongs_to :previous_membership, class_name: "Membership", optional: true
  belongs_to :new_membership, class_name: "Membership", optional: true
  belongs_to :actor_membership, class_name: "Membership"

  validates :reason, length: { maximum: REASON_LIMIT }

  def readonly?
    persisted?
  end
end
