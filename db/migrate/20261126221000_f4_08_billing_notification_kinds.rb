# frozen_string_literal: true

class F408BillingNotificationKinds < ActiveRecord::Migration[8.1]
  KINDS = %w[
    new_enquiry enquiry_assigned enquiry_reassigned_away clarification_answered
    quote_accepted quote_declined quote_changes_requested
    project_created project_assigned project_assignment_changed task_assigned
    schedule_confirmed schedule_cancelled project_update
    document_uploaded document_review_required document_changes_requested
    document_approved document_released document_release_revoked upload_requested
    inspection_assigned inspection_submitted
    report_review_required report_changes_requested report_approved report_released
    invoice_issued invoice_released payment_recorded payment_reversed invoice_voided
  ].freeze

  PREVIOUS = (KINDS - %w[invoice_issued invoice_released payment_recorded payment_reversed invoice_voided]).freeze

  def up
    execute <<~SQL
      ALTER TABLE staff_notifications DROP CONSTRAINT IF EXISTS staff_notifications_kind_check;
      ALTER TABLE staff_notifications
        ADD CONSTRAINT staff_notifications_kind_check
        CHECK (kind IN (#{KINDS.map { |k| ActiveRecord::Base.connection.quote(k) }.join(', ')}));
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE staff_notifications DROP CONSTRAINT IF EXISTS staff_notifications_kind_check;
      ALTER TABLE staff_notifications
        ADD CONSTRAINT staff_notifications_kind_check
        CHECK (kind IN (#{PREVIOUS.map { |k| ActiveRecord::Base.connection.quote(k) }.join(', ')}));
    SQL
  end
end
