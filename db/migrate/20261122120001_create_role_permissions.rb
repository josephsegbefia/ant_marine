# frozen_string_literal: true

class CreateRolePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :role_permissions do |t|
      t.string :role_key, null: false
      t.references :permission, null: false, foreign_key: true

      t.timestamps
    end

    add_index :role_permissions, %i[role_key permission_id], unique: true
    add_index :role_permissions, :role_key
  end
end
