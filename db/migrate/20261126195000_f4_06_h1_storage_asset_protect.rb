# frozen_string_literal: true

# F4-06-H1: bind scan evidence to digest; freeze storage asset identity after verification.
class F406H1StorageAssetProtect < ActiveRecord::Migration[8.1]
  def up
    add_column :storage_assets, :scanned_checksum_sha256, :string
    add_column :storage_assets, :scanner_adapter, :string

    execute <<~SQL
      UPDATE storage_assets
         SET scanned_checksum_sha256 = checksum_sha256,
             scanner_adapter = COALESCE(scan_result, 'legacy')
       WHERE scan_status = 'available'
         AND scanned_checksum_sha256 IS NULL;

      ALTER TABLE storage_assets
        ADD CONSTRAINT storage_assets_available_requires_scanned_checksum
        CHECK (
          scan_status <> 'available'
          OR (scanned_checksum_sha256 IS NOT NULL AND scanned_checksum_sha256 = checksum_sha256)
        );

      CREATE OR REPLACE FUNCTION ant_marine_storage_asset_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'UPDATE' THEN
          IF OLD.scan_status IN ('available', 'rejected') THEN
            IF NEW.checksum_sha256 IS DISTINCT FROM OLD.checksum_sha256
               OR NEW.storage_key IS DISTINCT FROM OLD.storage_key
               OR NEW.byte_size IS DISTINCT FROM OLD.byte_size
               OR NEW.content_type IS DISTINCT FROM OLD.content_type
               OR NEW.filename IS DISTINCT FROM OLD.filename
               OR NEW.active_storage_blob_id IS DISTINCT FROM OLD.active_storage_blob_id
               OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
               OR NEW.classification IS DISTINCT FROM OLD.classification
               OR NEW.encryption_key_version IS DISTINCT FROM OLD.encryption_key_version THEN
              PERFORM ant_marine_reject('Verified storage asset identity fields are immutable.');
            END IF;
          END IF;

          IF OLD.scan_status = 'available'
             AND NEW.scan_status IS DISTINCT FROM OLD.scan_status THEN
            PERFORM ant_marine_reject('Available storage assets cannot change scan status.');
          END IF;

          IF OLD.scan_status = 'rejected'
             AND NEW.scan_status = 'available' THEN
            PERFORM ant_marine_reject('Rejected storage assets cannot be marked available.');
          END IF;

          IF NEW.scan_status = 'available'
             AND (NEW.scanned_checksum_sha256 IS NULL
                  OR NEW.scanned_checksum_sha256 IS DISTINCT FROM NEW.checksum_sha256) THEN
            PERFORM ant_marine_reject('Available assets require scanned checksum matching content digest.');
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS storage_assets_protect ON storage_assets;
      CREATE TRIGGER storage_assets_protect
        BEFORE UPDATE ON storage_assets
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_storage_asset_protect();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS storage_assets_protect ON storage_assets;
      DROP FUNCTION IF EXISTS ant_marine_storage_asset_protect();
      ALTER TABLE storage_assets
        DROP CONSTRAINT IF EXISTS storage_assets_available_requires_scanned_checksum;
    SQL
    remove_column :storage_assets, :scanner_adapter
    remove_column :storage_assets, :scanned_checksum_sha256
  end
end
