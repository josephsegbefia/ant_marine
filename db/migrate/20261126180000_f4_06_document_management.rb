# frozen_string_literal: true

# F4-06 Package A: documents, versions, upload requests, review, release, access grants.
class F406DocumentManagement < ActiveRecord::Migration[8.1]
  def up
    create_table :documents do |t|
      t.references :operating_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.string :category, null: false
      t.string :classification, null: false, default: "standard"
      t.string :visibility_intent, null: false, default: "internal"
      t.string :workflow_status, null: false, default: "working_draft"
      t.bigint :current_version_id
      t.bigint :upload_request_id
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.text :description
      t.datetime :archived_at
      t.timestamps
    end

    add_index :documents, [ :project_id, :workflow_status ]
    add_index :documents, [ :client_organization_id, :workflow_status ]
    add_index :documents, :upload_request_id

    create_table :upload_requests do |t|
      t.references :project, null: false, foreign_key: true
      t.references :operating_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.string :title, null: false
      t.text :instructions
      t.string :document_category, null: false
      t.date :due_on
      t.string :status, null: false, default: "requested"
      t.references :requested_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.bigint :satisfied_document_id
      t.text :cancelled_reason
      t.timestamps
    end

    add_index :upload_requests, [ :project_id, :status ]
    add_index :upload_requests, :satisfied_document_id

    create_table :document_versions do |t|
      t.references :document, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.references :storage_asset, null: false, foreign_key: { to_table: :storage_assets }, index: { unique: true }
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false
      t.string :checksum_sha256, null: false
      t.references :uploaded_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :document_versions, [ :document_id, :version_number ], unique: true

    create_table :document_reviews do |t|
      t.references :document_version, null: false, foreign_key: true
      t.references :reviewer_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :outcome
      t.text :comments
      t.datetime :decided_at
      t.timestamps
    end

    add_index :document_reviews, [ :document_version_id, :reviewer_membership_id ],
              unique: true,
              where: "decided_at IS NULL",
              name: "index_document_reviews_open_per_version_reviewer"

    create_table :document_releases do |t|
      t.references :document, null: false, foreign_key: true
      t.references :document_version, null: false, foreign_key: true
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :released_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :released_at, null: false
      t.datetime :revoked_at
      t.text :revocation_reason
      t.string :classification, null: false, default: "standard"
      t.string :release_kind, null: false, default: "client_share"
      t.timestamps
    end

    add_index :document_releases, :document_id,
              unique: true,
              where: "revoked_at IS NULL",
              name: "index_document_releases_one_active_per_document"
    add_index :document_releases,
              [ :document_id, :client_organization_id ],
              unique: true,
              where: "revoked_at IS NULL",
              name: "index_document_releases_one_active_per_document_client"

    create_table :document_access_grants do |t|
      t.bigint :document_id
      t.bigint :project_id
      t.references :user, null: false, foreign_key: true
      t.references :granted_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_foreign_key :document_access_grants, :documents, column: :document_id
    add_foreign_key :document_access_grants, :projects, column: :project_id
    add_index :document_access_grants, [ :document_id, :user_id ], where: "revoked_at IS NULL"
    add_index :document_access_grants, [ :project_id, :user_id ], where: "revoked_at IS NULL"

    add_foreign_key :documents, :document_versions, column: :current_version_id
    add_foreign_key :documents, :upload_requests, column: :upload_request_id
    add_foreign_key :upload_requests, :documents, column: :satisfied_document_id

    execute <<~SQL
      ALTER TABLE documents
        ADD CONSTRAINT documents_classification_check
        CHECK (classification IN ('standard', 'confidential'));
      ALTER TABLE documents
        ADD CONSTRAINT documents_visibility_intent_check
        CHECK (visibility_intent IN ('internal', 'client_submitted', 'for_client_release'));
      ALTER TABLE documents
        ADD CONSTRAINT documents_workflow_status_check
        CHECK (workflow_status IN (
          'working_draft', 'submitted', 'changes_requested',
          'approved', 'released', 'archived'
        ));
      ALTER TABLE documents
        ADD CONSTRAINT documents_title_length
        CHECK (char_length(title) BETWEEN 1 AND 200);

      ALTER TABLE upload_requests
        ADD CONSTRAINT upload_requests_status_check
        CHECK (status IN (
          'requested', 'submitted', 'under_review', 'changes_required',
          'satisfied', 'cancelled'
        ));
      ALTER TABLE upload_requests
        ADD CONSTRAINT upload_requests_title_length
        CHECK (char_length(title) BETWEEN 1 AND 200);

      ALTER TABLE document_versions
        ADD CONSTRAINT document_versions_byte_size_positive
        CHECK (byte_size > 0);

      ALTER TABLE document_reviews
        ADD CONSTRAINT document_reviews_outcome_check
        CHECK (
          outcome IS NULL OR outcome IN ('approved', 'changes_requested')
        );
      ALTER TABLE document_reviews
        ADD CONSTRAINT document_reviews_open_or_decided_check
        CHECK (
          (outcome IS NULL AND decided_at IS NULL)
          OR (outcome IS NOT NULL AND decided_at IS NOT NULL)
        );

      ALTER TABLE document_releases
        ADD CONSTRAINT document_releases_classification_check
        CHECK (classification IN ('standard', 'confidential'));
      ALTER TABLE document_releases
        ADD CONSTRAINT document_releases_release_kind_check
        CHECK (release_kind IN ('client_share'));

      ALTER TABLE document_access_grants
        ADD CONSTRAINT document_access_grants_target_xor
        CHECK (
          (document_id IS NOT NULL AND project_id IS NULL)
          OR (document_id IS NULL AND project_id IS NOT NULL)
        );

      CREATE OR REPLACE FUNCTION ant_marine_document_version_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          PERFORM ant_marine_reject('Document versions cannot be deleted.');
        ELSIF TG_OP = 'UPDATE' THEN
          IF NEW.document_id IS DISTINCT FROM OLD.document_id
             OR NEW.version_number IS DISTINCT FROM OLD.version_number
             OR NEW.storage_asset_id IS DISTINCT FROM OLD.storage_asset_id
             OR NEW.checksum_sha256 IS DISTINCT FROM OLD.checksum_sha256
             OR NEW.filename IS DISTINCT FROM OLD.filename
             OR NEW.content_type IS DISTINCT FROM OLD.content_type
             OR NEW.byte_size IS DISTINCT FROM OLD.byte_size
             OR NEW.uploaded_by_membership_id IS DISTINCT FROM OLD.uploaded_by_membership_id THEN
            PERFORM ant_marine_reject('Document version identity fields are immutable.');
          END IF;
        END IF;
        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS document_versions_protect ON document_versions;
      CREATE TRIGGER document_versions_protect
        BEFORE UPDATE OR DELETE ON document_versions
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_document_version_protect();

      CREATE OR REPLACE FUNCTION ant_marine_document_release_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          PERFORM ant_marine_reject('Document releases cannot be deleted.');
        ELSIF TG_OP = 'UPDATE' THEN
          IF NEW.document_id IS DISTINCT FROM OLD.document_id
             OR NEW.document_version_id IS DISTINCT FROM OLD.document_version_id
             OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
             OR NEW.released_by_membership_id IS DISTINCT FROM OLD.released_by_membership_id
             OR NEW.released_at IS DISTINCT FROM OLD.released_at
             OR NEW.classification IS DISTINCT FROM OLD.classification
             OR NEW.release_kind IS DISTINCT FROM OLD.release_kind THEN
            PERFORM ant_marine_reject('Document release identity fields are immutable.');
          END IF;
          IF OLD.revoked_at IS NOT NULL
             AND (NEW.revoked_at IS DISTINCT FROM OLD.revoked_at
                  OR NEW.revocation_reason IS DISTINCT FROM OLD.revocation_reason) THEN
            PERFORM ant_marine_reject('Document release revocation cannot be changed after set.');
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS document_releases_protect ON document_releases;
      CREATE TRIGGER document_releases_protect
        BEFORE UPDATE OR DELETE ON document_releases
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_document_release_protect();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS document_releases_protect ON document_releases;
      DROP FUNCTION IF EXISTS ant_marine_document_release_protect();
      DROP TRIGGER IF EXISTS document_versions_protect ON document_versions;
      DROP FUNCTION IF EXISTS ant_marine_document_version_protect();
    SQL

    remove_foreign_key :upload_requests, column: :satisfied_document_id
    remove_foreign_key :documents, column: :upload_request_id
    remove_foreign_key :documents, column: :current_version_id

    drop_table :document_access_grants
    drop_table :document_releases
    drop_table :document_reviews
    drop_table :document_versions
    drop_table :upload_requests
    drop_table :documents
  end
end
