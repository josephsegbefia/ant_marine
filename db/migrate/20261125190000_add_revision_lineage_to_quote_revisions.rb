# frozen_string_literal: true

class AddRevisionLineageToQuoteRevisions < ActiveRecord::Migration[8.1]
  def change
    add_reference :quote_revisions, :predecessor_revision, foreign_key: { to_table: :quote_revisions }
    add_reference :quote_revisions, :superseded_by_revision, foreign_key: { to_table: :quote_revisions }
    add_column :quote_revisions, :revision_reason, :text
    add_column :quote_revisions, :superseded_at, :datetime

    add_check_constraint :quote_revisions,
                         "version_number = 1 OR (predecessor_revision_id IS NOT NULL AND revision_reason IS NOT NULL)",
                         name: "quote_revisions_later_versions_have_lineage"
    add_check_constraint :quote_revisions,
                         "revision_reason IS NULL OR char_length(revision_reason) <= 500",
                         name: "quote_revisions_reason_length"
    add_check_constraint :quote_revisions,
                         "revision_status <> 'superseded' OR superseded_at IS NOT NULL",
                         name: "quote_revisions_superseded_have_timestamp"
  end
end
