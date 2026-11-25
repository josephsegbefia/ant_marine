# frozen_string_literal: true

class F404bCommercialDecisionsAndHistory < ActiveRecord::Migration[8.1]
  def up
    create_table :client_contacts do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :full_name, null: false
      t.string :email
      t.string :phone
      t.string :job_title
      t.text :notes
      t.string :status, null: false, default: "active"
      t.references :created_by_membership, foreign_key: { to_table: :memberships }
      t.timestamps
    end
    add_index :client_contacts, [ :organization_id, :email ],
              unique: true,
              where: "email IS NOT NULL AND status = 'active'",
              name: "index_client_contacts_unique_active_email"
    add_check_constraint :client_contacts, "status IN ('active', 'archived')", name: "client_contacts_status_check"
    add_check_constraint :client_contacts, "char_length(full_name) BETWEEN 1 AND 120", name: "client_contacts_name_length"

    create_table :quote_responses do |t|
      t.references :quote, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true
      t.references :quote_portal_release, null: false, foreign_key: true
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :responded_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.bigint :responded_by_user_id, null: false
      t.string :response, null: false
      t.text :reason
      t.datetime :confirmed_at, null: false
      t.string :mode, null: false, default: "simulated"
      t.string :idempotency_key, null: false
      t.jsonb :offer_snapshot, null: false, default: {}
      t.jsonb :confirmation_evidence, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_foreign_key :quote_responses, :users, column: :responded_by_user_id
    add_index :quote_responses, :idempotency_key, unique: true
    add_index :quote_responses, [ :quote_portal_release_id, :response ],
              unique: true,
              where: "response IN ('accepted', 'declined')",
              name: "index_quote_responses_one_terminal_per_release"
    add_index :quote_responses, [ :client_organization_id, :created_at ],
              name: "index_quote_responses_on_org_and_created_at"
    add_check_constraint :quote_responses,
                         "response IN ('accepted', 'declined', 'changes_requested')",
                         name: "quote_responses_response_check"
    add_check_constraint :quote_responses,
                         "mode = 'simulated'",
                         name: "quote_responses_mode_check"
    add_check_constraint :quote_responses,
                         "response <> 'declined' OR (reason IS NOT NULL AND char_length(btrim(reason)) > 0)",
                         name: "quote_responses_decline_requires_reason"
    add_check_constraint :quote_responses,
                         "response <> 'changes_requested' OR (reason IS NOT NULL AND char_length(btrim(reason)) > 0)",
                         name: "quote_responses_changes_require_reason"

    execute <<~SQL
      CREATE OR REPLACE FUNCTION ant_marine_reject(message text)
      RETURNS void
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION '%', message USING ERRCODE = 'integrity_constraint_violation';
      END;
      $$;

      -- Test/DBA harness only. Application code must never enable this.
      -- Uses a transaction-local GUC so ordinary app sessions cannot leave a sticky bypass.
      CREATE OR REPLACE FUNCTION ant_marine_history_bypass_enabled()
      RETURNS boolean
      LANGUAGE sql
      STABLE
      AS $$
        SELECT coalesce(nullif(current_setting('ant_marine.history_bypass', true), ''), 'off') = 'on';
      $$;

      CREATE OR REPLACE FUNCTION ant_marine_quote_revision_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        allowed_status boolean;
      BEGIN
        IF ant_marine_history_bypass_enabled() THEN
          IF TG_OP = 'DELETE' THEN
            RETURN OLD;
          END IF;
          RETURN NEW;
        END IF;

        IF TG_OP = 'DELETE' THEN
          IF OLD.frozen_at IS NOT NULL THEN
            PERFORM ant_marine_reject('Frozen quotation versions cannot be deleted.');
          END IF;
          RETURN OLD;
        END IF;

        IF TG_OP = 'UPDATE' THEN
          IF OLD.frozen_at IS NOT NULL AND NEW.frozen_at IS NULL THEN
            PERFORM ant_marine_reject('A frozen quotation version cannot be unfrozen.');
          END IF;

          IF OLD.frozen_at IS NOT NULL THEN
            allowed_status :=
              (OLD.revision_status = NEW.revision_status) OR
              (OLD.revision_status = 'approved' AND NEW.revision_status IN ('issued', 'superseded')) OR
              (OLD.revision_status = 'issued' AND NEW.revision_status = 'superseded');

            IF NOT allowed_status THEN
              PERFORM ant_marine_reject('Frozen quotation version status change is not allowed.');
            END IF;

            IF NEW.title IS DISTINCT FROM OLD.title
               OR NEW.scope_description IS DISTINCT FROM OLD.scope_description
               OR NEW.deliverables IS DISTINCT FROM OLD.deliverables
               OR NEW.exclusions IS DISTINCT FROM OLD.exclusions
               OR NEW.additional_requirements IS DISTINCT FROM OLD.additional_requirements
               OR NEW.currency IS DISTINCT FROM OLD.currency
               OR NEW.subtotal_cents IS DISTINCT FROM OLD.subtotal_cents
               OR NEW.total_cents IS DISTINCT FROM OLD.total_cents
               OR NEW.valid_until IS DISTINCT FROM OLD.valid_until
               OR NEW.payment_terms IS DISTINCT FROM OLD.payment_terms
               OR NEW.commercial_exclusions IS DISTINCT FROM OLD.commercial_exclusions
               OR NEW.additional_conditions IS DISTINCT FROM OLD.additional_conditions
               OR NEW.internal_notes IS DISTINCT FROM OLD.internal_notes
               OR NEW.recipient_snapshot IS DISTINCT FROM OLD.recipient_snapshot
               OR NEW.approved_by_membership_id IS DISTINCT FROM OLD.approved_by_membership_id
               OR NEW.approved_at IS DISTINCT FROM OLD.approved_at
               OR NEW.prepared_by_membership_id IS DISTINCT FROM OLD.prepared_by_membership_id
               OR NEW.submitted_by_membership_id IS DISTINCT FROM OLD.submitted_by_membership_id
               OR NEW.contributor_membership_ids IS DISTINCT FROM OLD.contributor_membership_ids
               OR NEW.predecessor_revision_id IS DISTINCT FROM OLD.predecessor_revision_id
               OR NEW.revision_reason IS DISTINCT FROM OLD.revision_reason
               OR NEW.version_number IS DISTINCT FROM OLD.version_number
               OR NEW.quote_id IS DISTINCT FROM OLD.quote_id
               OR NEW.frozen_at IS DISTINCT FROM OLD.frozen_at THEN
              PERFORM ant_marine_reject('Frozen quotation commercial content cannot be changed.');
            END IF;
          END IF;
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER quote_revisions_history_protect
      BEFORE UPDATE OR DELETE ON quote_revisions
      FOR EACH ROW
      EXECUTE FUNCTION ant_marine_quote_revision_protect();

      CREATE OR REPLACE FUNCTION ant_marine_quote_line_item_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        old_frozen boolean := false;
        new_frozen boolean := false;
      BEGIN
        IF ant_marine_history_bypass_enabled() THEN
          IF TG_OP = 'DELETE' THEN
            RETURN OLD;
          END IF;
          RETURN NEW;
        END IF;

        IF TG_OP IN ('UPDATE', 'DELETE') THEN
          SELECT frozen_at IS NOT NULL INTO old_frozen
          FROM quote_revisions WHERE id = OLD.quote_revision_id;
        END IF;

        IF TG_OP IN ('INSERT', 'UPDATE') THEN
          SELECT frozen_at IS NOT NULL INTO new_frozen
          FROM quote_revisions WHERE id = NEW.quote_revision_id;
        END IF;

        IF TG_OP = 'INSERT' AND new_frozen THEN
          PERFORM ant_marine_reject('Line items cannot be added to a frozen quotation version.');
        ELSIF TG_OP = 'DELETE' AND old_frozen THEN
          PERFORM ant_marine_reject('Line items cannot be removed from a frozen quotation version.');
        ELSIF TG_OP = 'UPDATE' AND (old_frozen OR new_frozen) THEN
          PERFORM ant_marine_reject('Line items on a frozen quotation version cannot be changed.');
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER quote_line_items_history_protect
      BEFORE INSERT OR UPDATE OR DELETE ON quote_line_items
      FOR EACH ROW
      EXECUTE FUNCTION ant_marine_quote_line_item_protect();

      CREATE OR REPLACE FUNCTION ant_marine_quote_response_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF ant_marine_history_bypass_enabled() THEN
          IF TG_OP = 'DELETE' THEN
            RETURN OLD;
          END IF;
          RETURN NEW;
        END IF;

        PERFORM ant_marine_reject('Commercial decision records are append-only.');
        RETURN NULL;
      END;
      $$;

      CREATE TRIGGER quote_responses_history_protect
      BEFORE UPDATE OR DELETE ON quote_responses
      FOR EACH ROW
      EXECUTE FUNCTION ant_marine_quote_response_protect();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS quote_responses_history_protect ON quote_responses;
      DROP TRIGGER IF EXISTS quote_line_items_history_protect ON quote_line_items;
      DROP TRIGGER IF EXISTS quote_revisions_history_protect ON quote_revisions;
      DROP FUNCTION IF EXISTS ant_marine_quote_response_protect();
      DROP FUNCTION IF EXISTS ant_marine_quote_line_item_protect();
      DROP FUNCTION IF EXISTS ant_marine_quote_revision_protect();
      DROP FUNCTION IF EXISTS ant_marine_history_bypass_enabled();
      DROP FUNCTION IF EXISTS ant_marine_reject(text);
    SQL

    drop_table :quote_responses
    drop_table :client_contacts
  end
end
