# frozen_string_literal: true

class CreateQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :quotes do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :client_organization, foreign_key: { to_table: :organizations }, index: true
      t.references :service, foreign_key: true
      t.string :reference_number, null: false
      t.string :status, null: false, default: "draft"
      t.string :delivery_state, null: false, default: "not_prepared"
      t.jsonb :prospective_client, null: false, default: {}
      t.bigint :created_by_membership_id
      t.bigint :updated_by_membership_id
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :quotes, %i[organization_id reference_number], unique: true
    add_index :quotes, :status

    create_table :quote_revisions do |t|
      t.references :quote, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :revision_status, null: false, default: "draft"
      t.string :title
      t.text :scope_description
      t.text :deliverables
      t.text :exclusions
      t.text :additional_requirements
      t.string :currency, null: false, default: "GHS"
      t.bigint :subtotal_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0
      t.date :valid_until
      t.text :payment_terms
      t.text :commercial_exclusions
      t.text :additional_conditions
      t.text :internal_notes
      t.jsonb :recipient_snapshot, null: false, default: {}
      t.datetime :frozen_at
      t.bigint :approved_by_membership_id
      t.datetime :approved_at
      t.bigint :issued_by_membership_id
      t.datetime :issued_at
      t.timestamps
    end

    add_index :quote_revisions, %i[quote_id version_number], unique: true

    add_reference :quotes, :current_revision, foreign_key: { to_table: :quote_revisions }

    create_table :quote_line_items do |t|
      t.references :quote_revision, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :description, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false, default: 1
      t.string :unit, null: false, default: "each"
      t.bigint :unit_price_cents, null: false, default: 0
      t.bigint :line_total_cents, null: false, default: 0
      t.timestamps
    end

    add_index :quote_line_items, %i[quote_revision_id position]
  end
end
