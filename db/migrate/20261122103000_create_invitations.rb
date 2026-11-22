# frozen_string_literal: true

class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :email, null: false
      t.string :role_key, null: false
      t.string :token_digest, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.references :invited_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :accepted_by_user, foreign_key: { to_table: :users }
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :invitations, :token_digest, unique: true, where: "status = 'pending'", name: "index_invitations_unique_pending_token_digest"
    add_index :invitations, %i[organization_id status]
    add_index :invitations, %i[email organization_id]
    add_check_constraint :invitations,
      "status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'revoked'::character varying, 'expired'::character varying]::text[])",
      name: "invitations_status_check"
  end
end
