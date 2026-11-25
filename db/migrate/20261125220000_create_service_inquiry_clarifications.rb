# frozen_string_literal: true

class CreateServiceInquiryClarifications < ActiveRecord::Migration[8.1]
  def change
    create_table :service_inquiry_clarifications do |t|
      t.references :service_inquiry, null: false, foreign_key: true
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :subject, null: false
      t.text :questions, null: false
      t.text :prepared_message
      t.string :status, null: false, default: "prepared"
      t.string :contact_channel
      t.datetime :contacted_at
      t.references :contacted_by_membership, foreign_key: { to_table: :memberships }
      t.text :response_text
      t.string :response_source
      t.datetime :response_received_at
      t.references :response_recorded_by_membership, foreign_key: { to_table: :memberships }
      t.datetime :withdrawn_at
      t.references :withdrawn_by_membership, foreign_key: { to_table: :memberships }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_check_constraint :service_inquiry_clarifications,
                         "status IN ('prepared', 'contacted_outside_system', 'answered', 'withdrawn')",
                         name: "service_inquiry_clarifications_status_check"
    add_check_constraint :service_inquiry_clarifications,
                         "contact_channel IS NULL OR contact_channel IN ('phone', 'email_outside_system', 'in_person', 'other')",
                         name: "service_inquiry_clarifications_channel_check"
    add_check_constraint :service_inquiry_clarifications,
                         "response_source IS NULL OR response_source IN ('phone', 'email', 'in_person', 'other')",
                         name: "service_inquiry_clarifications_source_check"
    add_check_constraint :service_inquiry_clarifications,
                         "status <> 'contacted_outside_system' OR " \
                         "(contact_channel IS NOT NULL AND contacted_at IS NOT NULL AND contacted_by_membership_id IS NOT NULL)",
                         name: "service_inquiry_clarifications_contact_recorded"
    add_check_constraint :service_inquiry_clarifications,
                         "status <> 'answered' OR (response_text IS NOT NULL AND response_source IS NOT NULL AND " \
                         "response_received_at IS NOT NULL AND response_recorded_by_membership_id IS NOT NULL)",
                         name: "service_inquiry_clarifications_answer_recorded"
    add_check_constraint :service_inquiry_clarifications,
                         "status <> 'withdrawn' OR (withdrawn_at IS NOT NULL AND withdrawn_by_membership_id IS NOT NULL)",
                         name: "service_inquiry_clarifications_withdrawal_recorded"
    add_check_constraint :service_inquiry_clarifications,
                         "char_length(subject) <= 160 AND char_length(questions) <= 2000 AND " \
                         "char_length(coalesce(prepared_message, '')) <= 4000 AND char_length(coalesce(response_text, '')) <= 4000",
                         name: "service_inquiry_clarifications_length_check"
  end
end
