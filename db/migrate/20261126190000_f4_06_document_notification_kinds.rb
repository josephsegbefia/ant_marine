# frozen_string_literal: true

class F406DocumentNotificationKinds < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE staff_notifications DROP CONSTRAINT IF EXISTS staff_notifications_kind_check;
      ALTER TABLE staff_notifications
        ADD CONSTRAINT staff_notifications_kind_check
        CHECK (kind IN (
          'new_enquiry','enquiry_assigned','enquiry_reassigned_away','clarification_answered',
          'quote_accepted','quote_declined','quote_changes_requested',
          'project_created','project_assigned','project_assignment_changed',
          'task_assigned','schedule_confirmed','schedule_cancelled','project_update',
          'document_uploaded','document_review_required','document_changes_requested','document_approved',
          'document_released','document_release_revoked','upload_requested'
        ));
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE staff_notifications DROP CONSTRAINT IF EXISTS staff_notifications_kind_check;
      ALTER TABLE staff_notifications
        ADD CONSTRAINT staff_notifications_kind_check
        CHECK (kind IN (
          'new_enquiry','enquiry_assigned','enquiry_reassigned_away','clarification_answered',
          'quote_accepted','quote_declined','quote_changes_requested',
          'project_created','project_assigned','project_assignment_changed',
          'task_assigned','schedule_confirmed','schedule_cancelled','project_update'
        ));
    SQL
  end
end
