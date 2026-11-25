# frozen_string_literal: true

class AddTriageToServiceInquiries < ActiveRecord::Migration[8.1]
  def change
    change_table :service_inquiries, bulk: true do |t|
      t.references :assigned_membership, foreign_key: { to_table: :memberships }
      t.references :duplicate_of, foreign_key: { to_table: :service_inquiries }
      t.integer :lock_version, null: false, default: 0
      t.datetime :review_started_at
      t.datetime :qualified_at
      t.text :qualification_note
      t.string :closure_reason
      t.text :closure_note
      t.datetime :closed_at
    end

    add_index :service_inquiries, %i[organization_id assigned_membership_id current_status],
              name: "index_service_inquiries_on_org_assignee_status"

    add_check_constraint :service_inquiries,
                         "closure_reason IS NULL OR closure_reason IN ('cancelled', 'not_proceeding', 'other', 'outside_scope', 'duplicate')",
                         name: "service_inquiries_closure_reason_check"
    add_check_constraint :service_inquiries,
                         "(current_status IN ('closed', 'unqualified', 'merged')) = (closure_reason IS NOT NULL AND closed_at IS NOT NULL)",
                         name: "service_inquiries_closed_states_have_reason"
    add_check_constraint :service_inquiries,
                         "current_status <> 'closed' OR closure_reason IN ('cancelled', 'not_proceeding', 'other')",
                         name: "service_inquiries_closed_reason_matches"
    add_check_constraint :service_inquiries,
                         "current_status <> 'unqualified' OR (closure_reason = 'outside_scope' AND closure_note IS NOT NULL)",
                         name: "service_inquiries_unqualified_has_note"
    add_check_constraint :service_inquiries,
                         "current_status <> 'merged' OR (closure_reason = 'duplicate' AND duplicate_of_id IS NOT NULL AND duplicate_of_id <> id)",
                         name: "service_inquiries_merged_has_canonical"
    add_check_constraint :service_inquiries,
                         "closure_reason IS DISTINCT FROM 'other' OR closure_note IS NOT NULL",
                         name: "service_inquiries_other_reason_has_note"
    add_check_constraint :service_inquiries,
                         "char_length(coalesce(qualification_note, '')) <= 2000 AND char_length(coalesce(closure_note, '')) <= 2000",
                         name: "service_inquiries_triage_note_length"

    create_table :service_inquiry_assignments do |t|
      t.references :service_inquiry, null: false, foreign_key: true
      t.references :previous_membership, foreign_key: { to_table: :memberships }
      t.references :new_membership, foreign_key: { to_table: :memberships }
      t.references :actor_membership, null: false, foreign_key: { to_table: :memberships }
      t.text :reason
      t.datetime :created_at, null: false
    end
    add_check_constraint :service_inquiry_assignments,
                         "previous_membership_id IS DISTINCT FROM new_membership_id",
                         name: "service_inquiry_assignments_change_check"
    add_check_constraint :service_inquiry_assignments,
                         "reason IS NULL OR char_length(reason) <= 500",
                         name: "service_inquiry_assignments_reason_length"

    create_table :service_inquiry_notes do |t|
      t.references :service_inquiry, null: false, foreign_key: true
      t.references :author_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :corrects_note, foreign_key: { to_table: :service_inquiry_notes }, index: { unique: true }
      t.text :body, null: false
      t.datetime :created_at, null: false
    end
    add_check_constraint :service_inquiry_notes,
                         "char_length(btrim(body)) > 0 AND char_length(body) <= 4000",
                         name: "service_inquiry_notes_body_check"
  end
end
