# frozen_string_literal: true

class CreateStorageAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :storage_assets do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :uploaded_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :scan_status, null: false, default: "pending_upload"
      t.string :classification, null: false, default: "standard"
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false
      t.string :checksum_sha256, null: false
      t.string :storage_key, null: false
      t.integer :encryption_key_version, null: false
      t.references :active_storage_blob, null: true, foreign_key: { to_table: :active_storage_blobs }
      t.string :scan_result
      t.datetime :scanned_at
      t.string :rejected_reason

      t.timestamps
    end

    add_index :storage_assets, :storage_key, unique: true
    add_index :storage_assets, :scan_status

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          ALTER TABLE storage_assets
          ADD CONSTRAINT storage_assets_scan_status_check
          CHECK (scan_status IN ('pending_upload', 'scanning', 'available', 'rejected'))
        SQL
        execute <<~SQL.squish
          ALTER TABLE storage_assets
          ADD CONSTRAINT storage_assets_classification_check
          CHECK (classification IN ('standard', 'confidential'))
        SQL
      end
    end
  end
end
