# frozen_string_literal: true

module DocumentsHelper
  WORKFLOW_LABELS = {
    "working_draft" => "Working draft",
    "submitted" => "Submitted for review",
    "changes_requested" => "Changes requested",
    "approved" => "Approved",
    "released" => "Released to client",
    "archived" => "Archived"
  }.freeze

  VISIBILITY_LABELS = {
    "internal" => "Internal only",
    "client_submitted" => "Submitted by client",
    "for_client_release" => "Shared with client"
  }.freeze

  def document_workflow_badge_class(status)
    {
      "working_draft" => "ant-badge--muted",
      "submitted" => "ant-badge--info",
      "changes_requested" => "ant-badge--warn",
      "approved" => "ant-badge--success",
      "released" => "ant-badge--success",
      "archived" => "ant-badge--muted"
    }.fetch(status.to_s, "ant-badge--muted")
  end

  def document_workflow_label(status)
    WORKFLOW_LABELS.fetch(status.to_s, status.to_s.humanize)
  end

  def document_visibility_label(intent)
    VISIBILITY_LABELS.fetch(intent.to_s, intent.to_s.humanize)
  end

  def document_security_label(version)
    return "No file yet" unless version

    case version.security_status
    when "pending_upload", "scanning"
      "Uploaded — security checks pending"
    when "available"
      "Available"
    when "rejected"
      "Rejected — file not available"
    else
      version.security_status.to_s.humanize
    end
  end

  def document_security_badge_class(version)
    return "ant-badge--muted" unless version

    case version.security_status
    when "available" then "ant-badge--success"
    when "rejected" then "ant-badge--danger"
    else "ant-badge--warn"
    end
  end

  def upload_request_status_label(status)
    {
      "requested" => "Waiting for your file",
      "submitted" => "Submitted",
      "under_review" => "Under review",
      "changes_required" => "Please upload a replacement",
      "satisfied" => "Complete",
      "cancelled" => "Cancelled"
    }.fetch(status.to_s, status.to_s.humanize)
  end

  def client_can_view_documents?
    client_can_view_projects?
  end
end
