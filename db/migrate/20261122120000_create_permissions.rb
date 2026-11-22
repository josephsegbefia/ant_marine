# frozen_string_literal: true

class CreatePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :permissions do |t|
      t.string :key, null: false
      t.string :display_name, null: false
      t.text :description
      t.string :category, null: false
      t.string :domain, null: false
      t.string :override_rule, null: false, default: "yes"
      t.integer :catalogue_version, null: false, default: 1

      t.timestamps
    end

    add_index :permissions, :key, unique: true
    add_check_constraint :permissions,
          "override_rule::text = ANY (ARRAY['yes'::character varying, 'protected'::character varying, 'deny_only'::character varying]::text[])",
          name: "permissions_override_rule_check"
  end
end
