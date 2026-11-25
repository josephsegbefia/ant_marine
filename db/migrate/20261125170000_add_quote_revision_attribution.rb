# frozen_string_literal: true

class AddQuoteRevisionAttribution < ActiveRecord::Migration[8.1]
  def up
    add_reference :quote_revisions, :prepared_by_membership, foreign_key: { to_table: :memberships }
    add_reference :quote_revisions, :submitted_by_membership, foreign_key: { to_table: :memberships }
    add_column :quote_revisions, :contributor_membership_ids, :bigint, array: true, default: [], null: false

    # Attribute only versions that are still open. Approved and issued versions keep their
    # historical record unchanged.
    execute <<~SQL.squish
      UPDATE quote_revisions r
      SET prepared_by_membership_id = q.created_by_membership_id,
          contributor_membership_ids = ARRAY[q.created_by_membership_id]
      FROM quotes q
      WHERE r.quote_id = q.id
        AND r.frozen_at IS NULL
        AND q.created_by_membership_id IS NOT NULL
    SQL

    execute <<~SQL.squish
      UPDATE quote_revisions r
      SET submitted_by_membership_id = latest.actor_membership_id,
          contributor_membership_ids = array(
            SELECT DISTINCT unnest(r.contributor_membership_ids || ARRAY[latest.actor_membership_id])
          )
      FROM (
        SELECT DISTINCT ON (subject_id) subject_id, actor_membership_id
        FROM audit_events
        WHERE subject_type = 'Quote' AND event_type = 'quote.submit_for_review' AND actor_membership_id IS NOT NULL
        ORDER BY subject_id, occurred_at DESC
      ) latest
      WHERE r.quote_id = latest.subject_id
        AND r.frozen_at IS NULL
        AND r.revision_status = 'pending_review'
    SQL

    add_check_constraint :quote_revisions,
                         "approved_by_membership_id IS NULL OR (" \
                         "approved_by_membership_id IS DISTINCT FROM prepared_by_membership_id AND " \
                         "approved_by_membership_id IS DISTINCT FROM submitted_by_membership_id AND " \
                         "NOT (approved_by_membership_id = ANY (contributor_membership_ids)))",
                         name: "quote_revisions_approver_is_independent"
  end

  def down
    remove_check_constraint :quote_revisions, name: "quote_revisions_approver_is_independent"
    remove_column :quote_revisions, :contributor_membership_ids
    remove_reference :quote_revisions, :submitted_by_membership, foreign_key: { to_table: :memberships }
    remove_reference :quote_revisions, :prepared_by_membership, foreign_key: { to_table: :memberships }
  end
end
