# frozen_string_literal: true

class CreatePermissionOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :permission_overrides do |t|
      t.references :membership, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.string :effect, null: false
      t.references :granted_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.text :reason

      t.timestamps
    end

    add_index :permission_overrides, %i[membership_id permission_id], unique: true
    add_check_constraint :permission_overrides,
          "effect::text = ANY (ARRAY['allow'::character varying, 'deny'::character varying]::text[])",
          name: "permission_overrides_effect_check"
  end
end
