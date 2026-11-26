# frozen_string_literal: true

class F408Billing < ActiveRecord::Migration[8.1]
  def up
    create_table :invoices do |t|
      t.string :reference_number, null: false
      t.references :operating_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :project, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true
      t.references :quote_response, null: false, foreign_key: true
      t.jsonb :commercial_snapshot, null: false, default: {}
      t.string :mode, null: false, default: "simulated"
      t.string :issue_status, null: false, default: "draft"
      t.string :currency, null: false
      t.bigint :total_cents, null: false, default: 0
      t.text :description
      t.jsonb :billing_recipient_snapshot, null: false, default: {}
      t.date :issue_on
      t.date :due_on
      t.text :payment_terms_text
      t.datetime :issued_at
      t.references :issued_by_membership, foreign_key: { to_table: :memberships }
      t.datetime :voided_at
      t.references :voided_by_membership, foreign_key: { to_table: :memberships }
      t.text :void_reason
      t.references :storage_asset, foreign_key: { to_table: :storage_assets }
      t.string :artifact_checksum_sha256
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :invoices, :reference_number, unique: true
    add_index :invoices, [ :project_id, :issue_status ]
    add_index :invoices, [ :client_organization_id, :issue_status ]
    add_index :invoices, :due_on

    create_table :invoice_line_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.text :description, null: false
      t.decimal :quantity, null: false, precision: 12, scale: 3, default: 1
      t.string :unit, null: false, default: "Lot"
      t.bigint :unit_amount_cents, null: false
      t.bigint :line_total_cents, null: false
      t.integer :position, null: false, default: 1
      t.references :quote_line_item, foreign_key: true
      t.timestamps
    end

    add_index :invoice_line_items, [ :invoice_id, :position ]

    create_table :invoice_releases do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :released_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :released_at, null: false
      t.references :storage_asset, null: false, foreign_key: { to_table: :storage_assets }
      t.string :artifact_checksum_sha256, null: false
      t.datetime :revoked_at
      t.references :revoked_by_membership, foreign_key: { to_table: :memberships }
      t.text :revocation_reason
      t.timestamps
    end

    add_index :invoice_releases, [ :invoice_id, :revoked_at ]

    create_table :payment_records do |t|
      t.references :invoice, null: false, foreign_key: true
      t.bigint :amount_cents, null: false
      t.string :currency, null: false
      t.date :payment_on, null: false
      t.string :payment_method, null: false
      t.string :external_reference
      t.text :internal_note
      t.references :recorded_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :recorded_at, null: false
      t.timestamps
    end

    create_table :payment_reversals do |t|
      t.references :payment_record, null: false, foreign_key: true, index: { unique: true }
      t.bigint :amount_cents, null: false
      t.text :reason, null: false
      t.references :recorded_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :recorded_at, null: false
      t.timestamps
    end

    execute <<~SQL
      ALTER TABLE invoices
        ADD CONSTRAINT invoices_mode_check CHECK (mode = 'simulated'),
        ADD CONSTRAINT invoices_issue_status_check CHECK (issue_status IN ('draft', 'issued', 'void')),
        ADD CONSTRAINT invoices_total_cents_check CHECK (total_cents >= 0),
        ADD CONSTRAINT invoices_currency_check CHECK (currency IN ('GHS', 'USD', 'EUR', 'GBP'));

      ALTER TABLE invoice_line_items
        ADD CONSTRAINT invoice_line_items_quantity_check CHECK (quantity > 0),
        ADD CONSTRAINT invoice_line_items_unit_amount_check CHECK (unit_amount_cents >= 0),
        ADD CONSTRAINT invoice_line_items_line_total_check CHECK (line_total_cents >= 0);

      ALTER TABLE payment_records
        ADD CONSTRAINT payment_records_amount_check CHECK (amount_cents > 0),
        ADD CONSTRAINT payment_records_currency_check CHECK (currency IN ('GHS', 'USD', 'EUR', 'GBP'));

      ALTER TABLE payment_reversals
        ADD CONSTRAINT payment_reversals_amount_check CHECK (amount_cents > 0);

      CREATE OR REPLACE FUNCTION ant_marine_invoice_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF OLD.issue_status <> 'draft' THEN
            PERFORM ant_marine_reject('Issued or void invoices cannot be deleted.');
          END IF;
          RETURN OLD;
        END IF;

        IF TG_OP = 'UPDATE' THEN
          IF OLD.issue_status IN ('issued', 'void') THEN
            IF NEW.reference_number IS DISTINCT FROM OLD.reference_number
               OR NEW.operating_organization_id IS DISTINCT FROM OLD.operating_organization_id
               OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
               OR NEW.project_id IS DISTINCT FROM OLD.project_id
               OR NEW.quote_id IS DISTINCT FROM OLD.quote_id
               OR NEW.quote_revision_id IS DISTINCT FROM OLD.quote_revision_id
               OR NEW.quote_response_id IS DISTINCT FROM OLD.quote_response_id
               OR NEW.commercial_snapshot IS DISTINCT FROM OLD.commercial_snapshot
               OR NEW.mode IS DISTINCT FROM OLD.mode
               OR NEW.currency IS DISTINCT FROM OLD.currency
               OR NEW.total_cents IS DISTINCT FROM OLD.total_cents
               OR NEW.description IS DISTINCT FROM OLD.description
               OR NEW.billing_recipient_snapshot IS DISTINCT FROM OLD.billing_recipient_snapshot
               OR NEW.issue_on IS DISTINCT FROM OLD.issue_on
               OR NEW.due_on IS DISTINCT FROM OLD.due_on
               OR NEW.payment_terms_text IS DISTINCT FROM OLD.payment_terms_text
               OR NEW.issued_at IS DISTINCT FROM OLD.issued_at
               OR NEW.issued_by_membership_id IS DISTINCT FROM OLD.issued_by_membership_id
               OR NEW.storage_asset_id IS DISTINCT FROM OLD.storage_asset_id
               OR NEW.artifact_checksum_sha256 IS DISTINCT FROM OLD.artifact_checksum_sha256
               OR NEW.created_by_membership_id IS DISTINCT FROM OLD.created_by_membership_id THEN
              PERFORM ant_marine_reject('Issued invoice financial identity fields are immutable.');
            END IF;
          END IF;

          IF OLD.issue_status = 'void' THEN
            IF NEW.voided_at IS DISTINCT FROM OLD.voided_at
               OR NEW.voided_by_membership_id IS DISTINCT FROM OLD.voided_by_membership_id
               OR NEW.void_reason IS DISTINCT FROM OLD.void_reason
               OR NEW.issue_status IS DISTINCT FROM OLD.issue_status THEN
              PERFORM ant_marine_reject('Void invoice records cannot be changed.');
            END IF;
          END IF;

          IF OLD.issue_status = 'issued' AND NEW.issue_status NOT IN ('issued', 'void') THEN
            PERFORM ant_marine_reject('Issued invoices can only move to void.');
          END IF;
        END IF;

        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS invoices_protect ON invoices;
      CREATE TRIGGER invoices_protect
        BEFORE UPDATE OR DELETE ON invoices
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_invoice_protect();

      CREATE OR REPLACE FUNCTION ant_marine_invoice_line_item_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        parent_status text;
      BEGIN
        IF TG_OP = 'DELETE' THEN
          SELECT issue_status INTO parent_status FROM invoices WHERE id = OLD.invoice_id;
          IF parent_status IS DISTINCT FROM 'draft' THEN
            PERFORM ant_marine_reject('Invoice line items cannot be removed after issuance.');
          END IF;
          RETURN OLD;
        END IF;

        IF TG_OP = 'UPDATE' THEN
          SELECT issue_status INTO parent_status FROM invoices WHERE id = OLD.invoice_id;
          IF parent_status IS DISTINCT FROM 'draft' THEN
            PERFORM ant_marine_reject('Invoice line items are immutable after issuance.');
          END IF;
        END IF;

        IF TG_OP = 'INSERT' THEN
          SELECT issue_status INTO parent_status FROM invoices WHERE id = NEW.invoice_id;
          IF parent_status IS DISTINCT FROM 'draft' THEN
            PERFORM ant_marine_reject('Invoice line items cannot be added after issuance.');
          END IF;
        END IF;

        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS invoice_line_items_protect ON invoice_line_items;
      CREATE TRIGGER invoice_line_items_protect
        BEFORE INSERT OR UPDATE OR DELETE ON invoice_line_items
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_invoice_line_item_protect();

      CREATE OR REPLACE FUNCTION ant_marine_invoice_release_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          PERFORM ant_marine_reject('Invoice releases cannot be deleted.');
        ELSIF TG_OP = 'UPDATE' THEN
          IF NEW.invoice_id IS DISTINCT FROM OLD.invoice_id
             OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
             OR NEW.released_by_membership_id IS DISTINCT FROM OLD.released_by_membership_id
             OR NEW.released_at IS DISTINCT FROM OLD.released_at
             OR NEW.storage_asset_id IS DISTINCT FROM OLD.storage_asset_id
             OR NEW.artifact_checksum_sha256 IS DISTINCT FROM OLD.artifact_checksum_sha256 THEN
            PERFORM ant_marine_reject('Invoice release identity fields are immutable.');
          END IF;
          IF OLD.revoked_at IS NOT NULL
             AND (NEW.revoked_at IS DISTINCT FROM OLD.revoked_at
                  OR NEW.revocation_reason IS DISTINCT FROM OLD.revocation_reason
                  OR NEW.revoked_by_membership_id IS DISTINCT FROM OLD.revoked_by_membership_id) THEN
            PERFORM ant_marine_reject('Invoice release revocation cannot be changed after set.');
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS invoice_releases_protect ON invoice_releases;
      CREATE TRIGGER invoice_releases_protect
        BEFORE UPDATE OR DELETE ON invoice_releases
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_invoice_release_protect();

      CREATE OR REPLACE FUNCTION ant_marine_payment_record_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          PERFORM ant_marine_reject('Payment records cannot be deleted. Record a reversal instead.');
        ELSIF TG_OP = 'UPDATE' THEN
          IF NEW.invoice_id IS DISTINCT FROM OLD.invoice_id
             OR NEW.amount_cents IS DISTINCT FROM OLD.amount_cents
             OR NEW.currency IS DISTINCT FROM OLD.currency
             OR NEW.payment_on IS DISTINCT FROM OLD.payment_on
             OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
             OR NEW.external_reference IS DISTINCT FROM OLD.external_reference
             OR NEW.recorded_by_membership_id IS DISTINCT FROM OLD.recorded_by_membership_id
             OR NEW.recorded_at IS DISTINCT FROM OLD.recorded_at THEN
            PERFORM ant_marine_reject('Payment record financial fields are immutable.');
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS payment_records_protect ON payment_records;
      CREATE TRIGGER payment_records_protect
        BEFORE UPDATE OR DELETE ON payment_records
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_payment_record_protect();

      CREATE OR REPLACE FUNCTION ant_marine_payment_reversal_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          PERFORM ant_marine_reject('Payment reversals cannot be deleted.');
        ELSIF TG_OP = 'UPDATE' THEN
          PERFORM ant_marine_reject('Payment reversals cannot be changed.');
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS payment_reversals_protect ON payment_reversals;
      CREATE TRIGGER payment_reversals_protect
        BEFORE UPDATE OR DELETE ON payment_reversals
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_payment_reversal_protect();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS payment_reversals_protect ON payment_reversals;
      DROP TRIGGER IF EXISTS payment_records_protect ON payment_records;
      DROP TRIGGER IF EXISTS invoice_releases_protect ON invoice_releases;
      DROP TRIGGER IF EXISTS invoice_line_items_protect ON invoice_line_items;
      DROP TRIGGER IF EXISTS invoices_protect ON invoices;
      DROP FUNCTION IF EXISTS ant_marine_payment_reversal_protect();
      DROP FUNCTION IF EXISTS ant_marine_payment_record_protect();
      DROP FUNCTION IF EXISTS ant_marine_invoice_release_protect();
      DROP FUNCTION IF EXISTS ant_marine_invoice_line_item_protect();
      DROP FUNCTION IF EXISTS ant_marine_invoice_protect();
    SQL

    drop_table :payment_reversals
    drop_table :payment_records
    drop_table :invoice_releases
    drop_table :invoice_line_items
    drop_table :invoices
  end
end
