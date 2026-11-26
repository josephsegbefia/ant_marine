# frozen_string_literal: true

# In-app notice for one staff member, created from a recorded audit event. Never emailed.
class StaffNotification < ApplicationRecord
  KINDS = %w[
    new_enquiry enquiry_assigned enquiry_reassigned_away clarification_answered
    quote_accepted quote_declined quote_changes_requested
    project_created project_assigned project_assignment_changed
    task_assigned schedule_confirmed schedule_cancelled project_update
    document_uploaded document_review_required document_changes_requested document_approved
    document_released document_release_revoked upload_requested
    inspection_assigned inspection_submitted
    report_review_required report_changes_requested report_approved report_released
    invoice_issued invoice_released payment_recorded payment_reversed invoice_voided
  ].freeze

  belongs_to :organization
  belongs_to :recipient_membership, class_name: "Membership"
  belongs_to :audit_event

  validates :kind, inclusion: { in: KINDS }

  scope :unread, -> { where(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def read?
    read_at.present?
  end

  def kind_label
    {
      "new_enquiry" => "New enquiry",
      "enquiry_assigned" => "Assigned to you",
      "enquiry_reassigned_away" => "Reassigned",
      "clarification_answered" => "Client answer recorded",
      "quote_accepted" => "Quotation accepted",
      "quote_declined" => "Quotation declined",
      "quote_changes_requested" => "Changes requested",
      "project_created" => "Project created",
      "project_assigned" => "Project assignment",
      "project_assignment_changed" => "Assignment changed",
      "task_assigned" => "Task assigned",
      "schedule_confirmed" => "Schedule confirmed",
      "schedule_cancelled" => "Schedule cancelled",
      "project_update" => "Project update",
      "document_uploaded" => "Document uploaded",
      "document_review_required" => "Review needed",
      "document_changes_requested" => "Document changes requested",
      "document_approved" => "Document approved",
      "document_released" => "Released to client",
      "document_release_revoked" => "Client release withdrawn",
      "upload_requested" => "File requested",
      "inspection_assigned" => "Inspection assigned",
      "inspection_submitted" => "Inspection submitted",
      "report_review_required" => "Report review required",
      "report_changes_requested" => "Report changes requested",
      "report_approved" => "Report approved",
      "report_released" => "Report released to client",
      "invoice_issued" => "Invoice issued",
      "invoice_released" => "Invoice released to client",
      "payment_recorded" => "Payment recorded",
      "payment_reversed" => "Payment reversed",
      "invoice_voided" => "Invoice voided"
    }.fetch(kind)
  end

  def subject_record
    return @subject_record if defined?(@subject_record)

    @subject_record = case subject_type
    when "ServiceInquiry" then ServiceInquiry.find_by(id: subject_id)
    when "Quote" then Quote.find_by(id: subject_id)
    when "Project" then Project.find_by(id: subject_id)
    when "Document" then Document.find_by(id: subject_id)
    when "UploadRequest" then UploadRequest.find_by(id: subject_id)
    when "Inspection" then Inspection.find_by(id: subject_id)
    when "Report" then Report.find_by(id: subject_id)
    when "Invoice" then Invoice.find_by(id: subject_id)
    end
  end
end
