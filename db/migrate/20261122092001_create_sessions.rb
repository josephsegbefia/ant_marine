class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :membership_id
      t.string :ip_address
      t.string :user_agent
      t.integer :security_version_at_issue, null: false, default: 0
      t.datetime :revoked_at
      t.datetime :expires_at, null: false
      t.datetime :last_active_at, null: false

      t.timestamps
    end

    add_index :sessions, [ :user_id, :revoked_at ]
    add_index :sessions, :expires_at
  end
end
