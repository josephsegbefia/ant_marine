# frozen_string_literal: true

class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :organization, foreign_key: true
      t.references :actor_membership, foreign_key: { to_table: :memberships }
      t.string :event_type, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :audit_events, %i[organization_id occurred_at]
    add_index :audit_events, %i[event_type occurred_at]
    add_index :audit_events, %i[subject_type subject_id]
  end
end
