# frozen_string_literal: true

class F405H1ProjectCommercialProtect < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION ant_marine_project_commercial_protect()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'UPDATE' THEN
          IF NEW.mode IS DISTINCT FROM OLD.mode
             OR NEW.quote_id IS DISTINCT FROM OLD.quote_id
             OR NEW.quote_revision_id IS DISTINCT FROM OLD.quote_revision_id
             OR NEW.quote_response_id IS DISTINCT FROM OLD.quote_response_id
             OR NEW.quote_portal_release_id IS DISTINCT FROM OLD.quote_portal_release_id
             OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
             OR NEW.commercial_snapshot IS DISTINCT FROM OLD.commercial_snapshot THEN
            PERFORM ant_marine_reject('Project commercial source fields are immutable after creation.');
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS projects_commercial_protect ON projects;
      CREATE TRIGGER projects_commercial_protect
        BEFORE UPDATE ON projects
        FOR EACH ROW
        EXECUTE FUNCTION ant_marine_project_commercial_protect();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS projects_commercial_protect ON projects;
      DROP FUNCTION IF EXISTS ant_marine_project_commercial_protect();
    SQL
  end
end
