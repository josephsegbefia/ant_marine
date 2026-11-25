# frozen_string_literal: true

class ExpandStaffNotificationKindsForQuotes < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :staff_notifications, name: "staff_notifications_kind_check"
    add_check_constraint :staff_notifications,
                         "kind IN ('new_enquiry', 'enquiry_assigned', 'enquiry_reassigned_away', 'clarification_answered', 'quote_accepted', 'quote_declined', 'quote_changes_requested')",
                         name: "staff_notifications_kind_check"
  end

  def down
    remove_check_constraint :staff_notifications, name: "staff_notifications_kind_check"
    add_check_constraint :staff_notifications,
                         "kind IN ('new_enquiry', 'enquiry_assigned', 'enquiry_reassigned_away', 'clarification_answered')",
                         name: "staff_notifications_kind_check"
  end
end
