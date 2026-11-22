# frozen_string_literal: true

class AddPermissionEpochAtIssueToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :permission_epoch_at_issue, :integer, null: false, default: 0
  end
end
