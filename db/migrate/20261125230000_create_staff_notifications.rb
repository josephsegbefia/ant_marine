# frozen_string_literal: true

class CreateStaffNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_notifications do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :recipient_membership, null: false, foreign_key: { to_table: :memberships }, index: false
      t.references :audit_event, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :title, null: false
      t.string :dedupe_key, null: false
      t.datetime :read_at
      t.datetime :created_at, null: false
    end

    add_index :staff_notifications, %i[recipient_membership_id dedupe_key], unique: true,
              name: "index_staff_notifications_on_recipient_and_dedupe_key"
    add_index :staff_notifications, %i[recipient_membership_id read_at created_at],
              name: "index_staff_notifications_on_recipient_unread"
    add_check_constraint :staff_notifications,
                         "kind IN ('new_enquiry', 'enquiry_assigned', 'enquiry_reassigned_away', 'clarification_answered')",
                         name: "staff_notifications_kind_check"
    add_check_constraint :staff_notifications, "char_length(title) <= 200", name: "staff_notifications_title_length"
  end
end
