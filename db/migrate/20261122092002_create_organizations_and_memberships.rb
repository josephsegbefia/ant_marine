class CreateOrganizationsAndMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :kind, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, null: false, default: "active"
      t.jsonb :profile
      t.jsonb :settings
      t.datetime :archived_at

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
    add_index :organizations, [ :kind, :status ]
    add_check_constraint :organizations, "kind IN ('ant_marine', 'client')", name: "organizations_kind_check"
    add_check_constraint :organizations, "status IN ('active', 'archived')", name: "organizations_status_check"
    add_index :organizations, :kind,
              unique: true,
              where: "kind = 'ant_marine' AND archived_at IS NULL",
              name: "index_organizations_unique_active_ant_marine"

    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :role_key, null: false
      t.string :status, null: false, default: "invited"
      t.integer :permission_epoch, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.datetime :invited_at
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :memberships, [ :user_id, :organization_id ], unique: true
    add_index :memberships, [ :organization_id, :status ]
    add_index :memberships, [ :user_id, :status ]
    add_check_constraint :memberships,
                         "status IN ('invited', 'active', 'suspended', 'removed')",
                         name: "memberships_status_check"

    add_foreign_key :sessions, :memberships
    add_index :sessions, :membership_id
  end
end
