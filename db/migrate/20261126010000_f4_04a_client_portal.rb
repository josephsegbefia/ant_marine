# frozen_string_literal: true

class F404aClientPortal < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :reference_number, :string
    add_index :organizations, :reference_number, unique: true, where: "reference_number IS NOT NULL"

    create_table :quote_portal_releases do |t|
      t.references :quote, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :released_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :mode, null: false, default: "simulated"
      t.datetime :released_at, null: false
      t.datetime :revoked_at
      t.references :revoked_by_membership, foreign_key: { to_table: :memberships }
      t.string :label
      t.timestamps
    end

    add_index :quote_portal_releases, [ :quote_revision_id, :client_organization_id ],
              unique: true, name: "index_quote_portal_releases_unique_revision_org"
    add_index :quote_portal_releases, [ :client_organization_id, :released_at ],
              name: "index_quote_portal_releases_on_org_and_released_at"

    add_check_constraint :quote_portal_releases,
                         "mode IN ('simulated')",
                         name: "quote_portal_releases_mode_check"
  end
end
