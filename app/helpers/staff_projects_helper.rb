# frozen_string_literal: true

module StaffProjectsHelper
  PROJECT_ACTION_LABELS = {
    "mark_scheduled" => "Mark scheduled",
    "start_work" => "Start work",
    "enter_technical_review" => "Enter technical review",
    "mark_report_ready" => "Mark report ready",
    "complete" => "Mark complete",
    "close" => "Close project",
    "place_on_hold" => "Place on hold",
    "resume" => "Resume project",
    "cancel" => "Cancel project"
  }.freeze

  def project_status_badge_variant(status)
    case status.to_s
    when "planning", "scheduled" then "ant-badge--blue"
    when "in_progress", "technical_review", "report_ready" then "ant-badge--teal"
    when "on_hold" then "ant-badge--warn"
    when "completed", "closed" then "ant-badge--good"
    else "ant-badge--muted"
    end
  end

  def project_action_label(action)
    PROJECT_ACTION_LABELS.fetch(action.to_s, action.to_s.tr("_", " ").humanize)
  end

  def project_header_description(project)
    [
      project.client_organization.name,
      project.location.presence,
      project.service&.name.presence || project.title
    ].compact.join(" · ")
  end

  def project_coordinator_label(project)
    membership = project.coordinator_membership
    return "Not assigned" unless membership

    membership.user.full_name.presence || membership.user.email
  end

  def project_document_count(project)
    policy_scope(Document).where(project_id: project.id).not_archived.count
  end

  def project_active_team_count(project, assignments: nil)
    return assignments.count(&:active?) if assignments

    project.active_assignments.size
  end

  def project_milestone_status_label(milestone)
    case milestone.status
    when "completed" then "Done"
    when "cancelled" then "Cancelled"
    else
      milestone.evidence_gated? ? "Waiting" : "Not started"
    end
  end

  def project_milestone_badge_variant(milestone)
    case milestone.status
    when "completed" then "ant-badge--good"
    when "cancelled" then "ant-badge--muted"
    else
      milestone.evidence_gated? ? "ant-badge--warn" : "ant-badge--blue"
    end
  end

  def project_attention_items(project, doc_count:, actions:, assignments: nil, milestones: nil, tasks: nil)
    items = []
    team_empty = if assignments
      assignments.none?(&:active?)
    else
      project.active_assignments.empty?
    end

    if team_empty
      items << {
        icon: "users",
        title: "Assign the team",
        detail: "Choose who will deliver this project.",
        path: staff_project_path(project, tab: "team"),
        badge: "Needed",
        badge_class: "ant-badge--warn"
      }
    end

    if project.coordinator_membership_id.blank?
      items << {
        icon: "users",
        title: "Choose a coordinator",
        detail: "Someone needs to own day-to-day progress.",
        path: staff_project_path(project, tab: "team"),
        badge: "Needed",
        badge_class: "ant-badge--warn"
      }
    end

    milestone_list = milestones || project.project_milestones.to_a
    next_milestone = milestone_list.find { |m| m.status == "pending" && !m.evidence_gated? }
    if next_milestone
      items << {
        icon: "layers",
        title: next_milestone.title,
        detail: "Next milestone on the work checklist.",
        path: staff_project_path(project, tab: "milestones"),
        badge: "Next",
        badge_class: "ant-badge--blue"
      }
    end

    if doc_count.zero?
      items << {
        icon: "folder",
        title: "No documents yet",
        detail: "Upload working files or request what the client still needs to send.",
        path: staff_project_documents_path(project),
        badge: "Waiting",
        badge_class: "ant-badge--warn"
      }
    end

    task_list = tasks || project.tasks.to_a
    blocked = task_list.count { |task| task.status == "blocked" }
    if blocked.positive?
      items << {
        icon: "clipboard",
        title: "#{blocked} blocked #{blocked == 1 ? "task" : "tasks"}",
        detail: "Clear blockers so delivery can move again.",
        path: staff_project_path(project, tab: "tasks"),
        badge: "Attention",
        badge_class: "ant-badge--warn"
      }
    end

    if items.empty? && actions.blank?
      items << {
        icon: "check",
        title: "Nothing waiting right now",
        detail: "Use the tabs above for team, milestones, schedule and documents.",
        path: nil,
        badge: nil,
        badge_class: nil
      }
    end

    items.first(4)
  end
end
