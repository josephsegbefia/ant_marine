# frozen_string_literal: true

# F4-07 Package A: inspection templates, inspections, findings, evidence, reports.
class F407InspectionsReports < ActiveRecord::Migration[8.1]
  def up
    create_table :inspection_templates do |t|
      t.references :operating_organization, null: false, foreign_key: { to_table: :organizations }
      t.string :key, null: false
      t.string :title, null: false
      t.text :description
      t.references :service, foreign_key: true
      t.string :status, null: false, default: "draft"
      t.bigint :current_version_id
      t.timestamps
    end

    add_index :inspection_templates, [ :operating_organization_id, :key ], unique: true
    add_index :inspection_templates, [ :operating_organization_id, :status ]

    create_table :inspection_template_versions do |t|
      t.references :inspection_template, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.jsonb :schema_json, null: false, default: {}
      t.datetime :published_at
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :inspection_template_versions,
              [ :inspection_template_id, :version_number ],
              unique: true,
              name: "index_inspection_template_versions_on_template_and_number"

    add_foreign_key :inspection_templates, :inspection_template_versions, column: :current_version_id

    create_table :inspections do |t|
      t.string :reference_number, null: false
      t.references :operating_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :project, null: false, foreign_key: true
      t.references :service, foreign_key: true
      t.references :inspection_template_version, null: false, foreign_key: true
      t.bigint :schedule_event_id
      t.string :title, null: false
      t.string :inspection_type, null: false
      t.string :vessel_name
      t.string :location
      t.string :status, null: false, default: "draft"
      t.references :assigned_surveyor_membership, foreign_key: { to_table: :memberships }
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :mode, null: false, default: "simulated"
      t.text :operational_instructions
      t.datetime :submitted_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.text :cancellation_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :inspections, :reference_number, unique: true
    add_index :inspections, [ :project_id, :status ]
    add_index :inspections, :schedule_event_id
    add_foreign_key :inspections, :schedule_events, column: :schedule_event_id

    create_table :inspection_checklist_responses do |t|
      t.references :inspection, null: false, foreign_key: true
      t.string :item_key, null: false
      t.string :response_type, null: false
      t.jsonb :value_json, null: false, default: {}
      t.text :not_applicable_reason
      t.references :updated_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :inspection_checklist_responses,
              [ :inspection_id, :item_key ],
              unique: true,
              name: "index_inspection_checklist_responses_on_inspection_and_item"

    create_table :inspection_findings do |t|
      t.references :inspection, null: false, foreign_key: true
      t.string :reference_number, null: false
      t.string :checklist_item_key
      t.string :title, null: false
      t.text :observation, null: false
      t.text :recommendation
      t.string :location_or_equipment
      t.string :classification, null: false, default: "observation"
      t.string :status, null: false, default: "draft"
      t.references :recorded_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :recorded_at, null: false
      t.timestamps
    end

    add_index :inspection_findings, [ :inspection_id, :reference_number ], unique: true

    create_table :inspection_evidence_links do |t|
      t.references :inspection, null: false, foreign_key: true
      t.references :document_version, null: false, foreign_key: true
      t.references :finding, foreign_key: { to_table: :inspection_findings }
      t.string :checklist_item_key
      t.references :attached_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :attached_at, null: false
      t.timestamps
    end

    add_index :inspection_evidence_links,
              [ :inspection_id, :document_version_id, :checklist_item_key ],
              unique: true,
              name: "index_inspection_evidence_links_unique_attachment"

    create_table :reports do |t|
      t.string :reference_number, null: false
      t.references :operating_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :project, null: false, foreign_key: true
      t.references :inspection, foreign_key: true
      t.string :title, null: false
      t.string :report_kind, null: false, default: "technical_report"
      t.string :mode, null: false, default: "simulated"
      t.bigint :current_version_id
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.timestamps
    end

    add_index :reports, :reference_number, unique: true
    add_index :reports, [ :project_id, :report_kind ]

    create_table :report_versions do |t|
      t.references :report, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :status, null: false, default: "draft"
      t.string :title, null: false
      t.jsonb :content_json, null: false, default: {}
      t.references :authored_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :submitted_by_membership, foreign_key: { to_table: :memberships }
      t.references :storage_asset, foreign_key: { to_table: :storage_assets }
      t.string :artifact_checksum_sha256
      t.timestamps
    end

    add_index :report_versions, [ :report_id, :version_number ], unique: true

    add_foreign_key :reports, :report_versions, column: :current_version_id

    create_table :report_reviews do |t|
      t.references :report_version, null: false, foreign_key: true
      t.references :reviewer_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :outcome, null: false
      t.text :comments
      t.datetime :decided_at, null: false
      t.timestamps
    end

    add_index :report_reviews, [ :report_version_id, :reviewer_membership_id ]

    create_table :report_releases do |t|
      t.references :report, null: false, foreign_key: true
      t.references :report_version, null: false, foreign_key: true
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :released_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :released_at, null: false
      t.datetime :revoked_at
      t.text :revocation_reason
      t.string :artifact_checksum_sha256, null: false
      t.timestamps
    end

    add_index :report_releases, :report_id,
              unique: true,
              where: "revoked_at IS NULL",
              name: "index_report_releases_one_active_per_report"
    add_index :report_releases,
              [ :report_id, :client_organization_id ],
              unique: true,
              where: "revoked_at IS NULL",
              name: "index_report_releases_one_active_per_report_client"

    execute <<~SQL
      ALTER TABLE inspection_templates
        ADD CONSTRAINT inspection_templates_status_check
        CHECK (status IN ('draft', 'published', 'archived'));
      ALTER TABLE inspection_templates
        ADD CONSTRAINT inspection_templates_title_length
        CHECK (char_length(title) BETWEEN 1 AND 200);

      ALTER TABLE inspections
        ADD CONSTRAINT inspections_status_check
        CHECK (status IN (
          'draft', 'assigned', 'in_progress', 'submitted',
          'corrections_requested', 'completed', 'cancelled'
        ));
      ALTER TABLE inspections
        ADD CONSTRAINT inspections_mode_check
        CHECK (mode IN ('simulated'));
      ALTER TABLE inspections
        ADD CONSTRAINT inspections_title_length
        CHECK (char_length(title) BETWEEN 1 AND 200);

      ALTER TABLE inspection_findings
        ADD CONSTRAINT inspection_findings_classification_check
        CHECK (classification IN ('observation', 'deficiency', 'recommendation', 'other'));
      ALTER TABLE inspection_findings
        ADD CONSTRAINT inspection_findings_status_check
        CHECK (status IN ('draft', 'recorded', 'included_in_report'));

      ALTER TABLE report_versions
        ADD CONSTRAINT report_versions_status_check
        CHECK (status IN ('draft', 'submitted_for_review', 'changes_requested', 'approved'));

      ALTER TABLE report_reviews
        ADD CONSTRAINT report_reviews_outcome_check
        CHECK (outcome IN ('approved', 'changes_requested'));

      ALTER TABLE reports
        ADD CONSTRAINT reports_mode_check
        CHECK (mode IN ('simulated'));
      ALTER TABLE reports
        ADD CONSTRAINT reports_title_length
        CHECK (char_length(title) BETWEEN 1 AND 200);

      CREATE OR REPLACE FUNCTION ant_marine_inspection_template_version_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          PERFORM ant_marine_reject('Inspection template versions cannot be deleted.');
        ELSIF TG_OP = 'UPDATE' THEN
          IF NEW.inspection_template_id IS DISTINCT FROM OLD.inspection_template_id
             OR NEW.version_number IS DISTINCT FROM OLD.version_number
             OR NEW.schema_json IS DISTINCT FROM OLD.schema_json
             OR NEW.published_at IS DISTINCT FROM OLD.published_at
             OR NEW.created_by_membership_id IS DISTINCT FROM OLD.created_by_membership_id
             OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            PERFORM ant_marine_reject('Inspection template version identity fields are immutable.');
          END IF;
        END IF;
        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS inspection_template_versions_protect ON inspection_template_versions;
      CREATE TRIGGER inspection_template_versions_protect
        BEFORE UPDATE OR DELETE ON inspection_template_versions
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_inspection_template_version_protect();

      CREATE OR REPLACE FUNCTION ant_marine_report_version_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          PERFORM ant_marine_reject('Report versions cannot be deleted.');
        ELSIF TG_OP = 'UPDATE' THEN
          IF NEW.report_id IS DISTINCT FROM OLD.report_id
             OR NEW.version_number IS DISTINCT FROM OLD.version_number
             OR NEW.authored_by_membership_id IS DISTINCT FROM OLD.authored_by_membership_id THEN
            PERFORM ant_marine_reject('Report version identity fields are immutable.');
          END IF;
          IF OLD.status IS DISTINCT FROM 'draft' THEN
            IF NEW.title IS DISTINCT FROM OLD.title
               OR NEW.content_json IS DISTINCT FROM OLD.content_json THEN
              PERFORM ant_marine_reject('Report version content is immutable after leaving draft.');
            END IF;
          END IF;
          IF OLD.status = 'approved' THEN
            IF NEW.storage_asset_id IS DISTINCT FROM OLD.storage_asset_id
               OR NEW.artifact_checksum_sha256 IS DISTINCT FROM OLD.artifact_checksum_sha256 THEN
              PERFORM ant_marine_reject('Approved report version artifacts are immutable.');
            END IF;
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS report_versions_protect ON report_versions;
      CREATE TRIGGER report_versions_protect
        BEFORE UPDATE OR DELETE ON report_versions
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_report_version_protect();

      CREATE OR REPLACE FUNCTION ant_marine_report_release_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          PERFORM ant_marine_reject('Report releases cannot be deleted.');
        ELSIF TG_OP = 'UPDATE' THEN
          IF NEW.report_id IS DISTINCT FROM OLD.report_id
             OR NEW.report_version_id IS DISTINCT FROM OLD.report_version_id
             OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
             OR NEW.released_by_membership_id IS DISTINCT FROM OLD.released_by_membership_id
             OR NEW.released_at IS DISTINCT FROM OLD.released_at
             OR NEW.artifact_checksum_sha256 IS DISTINCT FROM OLD.artifact_checksum_sha256 THEN
            PERFORM ant_marine_reject('Report release identity fields are immutable.');
          END IF;
          IF OLD.revoked_at IS NOT NULL
             AND (NEW.revoked_at IS DISTINCT FROM OLD.revoked_at
                  OR NEW.revocation_reason IS DISTINCT FROM OLD.revocation_reason) THEN
            PERFORM ant_marine_reject('Report release revocation cannot be changed after set.');
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS report_releases_protect ON report_releases;
      CREATE TRIGGER report_releases_protect
        BEFORE UPDATE OR DELETE ON report_releases
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_report_release_protect();

      CREATE OR REPLACE FUNCTION ant_marine_inspection_evidence_link_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        insp_status text;
      BEGIN
        IF TG_OP = 'DELETE' THEN
          SELECT status INTO insp_status FROM inspections WHERE id = OLD.inspection_id;
          IF insp_status IN ('submitted', 'corrections_requested', 'completed') THEN
            PERFORM ant_marine_reject('Evidence links cannot be removed after inspection submission.');
          END IF;
        END IF;
        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS inspection_evidence_links_protect ON inspection_evidence_links;
      CREATE TRIGGER inspection_evidence_links_protect
        BEFORE DELETE ON inspection_evidence_links
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_inspection_evidence_link_protect();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS inspection_evidence_links_protect ON inspection_evidence_links;
      DROP FUNCTION IF EXISTS ant_marine_inspection_evidence_link_protect();
      DROP TRIGGER IF EXISTS report_releases_protect ON report_releases;
      DROP FUNCTION IF EXISTS ant_marine_report_release_protect();
      DROP TRIGGER IF EXISTS report_versions_protect ON report_versions;
      DROP FUNCTION IF EXISTS ant_marine_report_version_protect();
      DROP TRIGGER IF EXISTS inspection_template_versions_protect ON inspection_template_versions;
      DROP FUNCTION IF EXISTS ant_marine_inspection_template_version_protect();
    SQL

    remove_foreign_key :reports, column: :current_version_id
    remove_foreign_key :inspection_templates, column: :current_version_id
    remove_foreign_key :inspections, column: :schedule_event_id

    drop_table :report_releases
    drop_table :report_reviews
    drop_table :report_versions
    drop_table :reports
    drop_table :inspection_evidence_links
    drop_table :inspection_findings
    drop_table :inspection_checklist_responses
    drop_table :inspections
    drop_table :inspection_template_versions
    drop_table :inspection_templates
  end
end
