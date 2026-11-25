# frozen_string_literal: true

class CreateQuoteDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_deliveries do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true
      t.references :requested_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :dispatched_by_membership, foreign_key: { to_table: :memberships }
      t.string :channel, null: false, default: "email"
      t.string :status, null: false, default: "prepared"
      t.string :delivery_adapter, null: false
      t.string :idempotency_key, null: false
      t.string :recipient_email, null: false
      t.string :recipient_name
      t.string :recipient_company
      t.integer :attempt_count, null: false, default: 0
      t.datetime :prepared_at, null: false
      t.datetime :queued_at
      t.datetime :attempted_at
      t.datetime :accepted_at
      t.datetime :failed_at
      t.datetime :confirmed_at
      t.datetime :cancelled_at
      t.string :provider_message_id
      t.string :provider_response
      t.string :failure_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :quote_deliveries, :idempotency_key, unique: true
    add_index :quote_deliveries, :quote_revision_id, unique: true,
              where: "status IN ('prepared', 'queued', 'sending', 'accepted_by_provider', 'outcome_unknown', 'delivery_confirmed')",
              name: "index_quote_deliveries_one_live_per_revision"
    add_check_constraint :quote_deliveries, "channel IN ('email')", name: "quote_deliveries_channel_check"
    add_check_constraint :quote_deliveries,
                         "status IN ('prepared', 'queued', 'sending', 'accepted_by_provider', 'failed', 'outcome_unknown', " \
                         "'delivery_confirmed', 'cancelled')",
                         name: "quote_deliveries_status_check"
    add_check_constraint :quote_deliveries,
                         "status <> 'delivery_confirmed' OR (confirmed_at IS NOT NULL AND provider_message_id IS NOT NULL)",
                         name: "quote_deliveries_confirmation_needs_evidence"
    add_check_constraint :quote_deliveries,
                         "status <> 'accepted_by_provider' OR accepted_at IS NOT NULL",
                         name: "quote_deliveries_accepted_has_timestamp"
  end
end
