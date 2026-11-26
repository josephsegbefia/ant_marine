# frozen_string_literal: true

# F4-04B-H1: remove ant_marine.history_bypass from protect functions.
# Ordinary runtime roles can SET custom GUCs; a GUC-gated bypass is not a privilege boundary.
class F404bH1RemoveHistoryBypass < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION ant_marine_quote_revision_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        allowed_status boolean;
      BEGIN
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

      CREATE OR REPLACE FUNCTION ant_marine_quote_line_item_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        old_frozen boolean := false;
        new_frozen boolean := false;
      BEGIN
        IF TG_OP IN ('UPDATE', 'DELETE') THEN
          SELECT frozen_at IS NOT NULL INTO old_frozen
          FROM quote_revisions WHERE id = OLD.quote_revision_id
          FOR UPDATE;
        END IF;

        IF TG_OP IN ('INSERT', 'UPDATE') THEN
          SELECT frozen_at IS NOT NULL INTO new_frozen
          FROM quote_revisions WHERE id = NEW.quote_revision_id
          FOR UPDATE;
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

      CREATE OR REPLACE FUNCTION ant_marine_quote_response_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        PERFORM ant_marine_reject('Commercial decision records are append-only.');
        RETURN NULL;
      END;
      $$;

      DROP FUNCTION IF EXISTS ant_marine_history_bypass_enabled();
    SQL

    # Deny TRUNCATE on protected history tables for PUBLIC; owners still can (production gate: runtime is non-owner).
    execute <<~SQL
      REVOKE TRUNCATE ON quote_revisions FROM PUBLIC;
      REVOKE TRUNCATE ON quote_line_items FROM PUBLIC;
      REVOKE TRUNCATE ON quote_responses FROM PUBLIC;
    SQL
  end

  def down
    execute <<~SQL
      CREATE OR REPLACE FUNCTION ant_marine_history_bypass_enabled()
      RETURNS boolean
      LANGUAGE sql
      STABLE
      AS $$
        SELECT coalesce(nullif(current_setting('ant_marine.history_bypass', true), ''), 'off') = 'on';
      $$;
    SQL

    say "Restoring pre-H1 protect functions requires re-running F4-04B migration SQL; prefer structure.sql rollback."
  end
end
