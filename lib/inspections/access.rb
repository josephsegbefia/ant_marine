# frozen_string_literal: true

module Inspections
  # F4-07 inspection access contract — mirrors Documents::Access assignment gates.
  module Access
    module_function

    def can_list_project_inspections?(membership, project)
      return false unless membership&.status == "active" && project.is_a?(Project)
      return false if project.simulated? && Rails.env.production?

      if membership.staff_domain?
        staff_project_visible?(membership, project)
      elsif membership.client_domain?
        client_project_visible?(membership, project)
      else
        false
      end
    end

    def visible_inspections_for_project(membership, project)
      base = Inspection.where(project_id: project.id)
      return Inspection.none unless can_list_project_inspections?(membership, project)

      if membership.staff_domain?
        return base if effective(membership).allowed?("projects.view_all")
        return base if delivery_participant?(membership, project)

        assignment = assignment_scope(membership, project)
        case assignment
        when "review"
          base.where.not(status: "draft")
        when "delivery"
          base.where(assigned_surveyor_membership_id: membership.id)
              .or(base.where(created_by_membership_id: membership.id))
        when "collaborator"
          base.where(assigned_surveyor_membership_id: membership.id)
        else
          Inspection.none
        end
      elsif membership.client_domain?
        base.where.not(status: %w[draft cancelled])
      else
        Inspection.none
      end
    end

    def can_view?(membership, inspection)
      return false unless membership&.status == "active" && inspection.is_a?(Inspection)
      return false if inspection.project.simulated? && Rails.env.production?

      project = inspection.project
      if membership.staff_domain?
        return false unless project.operating_organization_id == membership.organization_id
        return true if effective(membership).allowed?("projects.view_all")
        return false unless assigned_any_scope?(membership, project)

        scope = assignment_scope(membership, project)
        return true if scope == "delivery"
        return true if scope == "review" && inspection.status != "draft"
        return true if inspection.assigned_surveyor_membership_id == membership.id
        return true if effective(membership).allowed?("inspections.view")

        false
      elsif membership.client_domain?
        return false unless client_project_visible?(membership, project)

        !inspection.status.in?(%w[draft cancelled])
      else
        false
      end
    end

    def can_edit_checklist?(membership, inspection)
      return false unless can_view?(membership, inspection)
      return false unless membership.staff_domain?
      return false unless inspection.editable_checklist?
      return false unless effective(membership).allowed?("inspections.edit")

      project = inspection.project
      return true if effective(membership).allowed?("projects.view_all")
      return true if inspection.assigned_surveyor_membership_id == membership.id

      delivery_participant?(membership, project) && inspection.assigned_surveyor_membership_id == membership.id
    end

    def can_manage_templates?(membership)
      return false unless membership&.status == "active" && membership.staff_domain?

      effective(membership).allowed?("projects.manage") || effective(membership).allowed?("projects.view_all")
    end

    def can_coordinate?(membership, inspection)
      return false unless can_view?(membership, inspection)
      return false unless membership.staff_domain?

      return true if effective(membership).allowed?("projects.manage")

      scope = assignment_scope(membership, inspection.project)
      scope == "review" && effective(membership).allowed?("reports.review")
    end

    def delivery_participant?(membership, project)
      Delivery::Access.delivery_participant?(membership, project)
    end

    def assigned_any_scope?(membership, project)
      Delivery::Access.assigned_any_scope?(membership, project)
    end

    def effective(membership)
      Authorization::EffectivePermissions.new(membership)
    end

    def staff_project_visible?(membership, project)
      return false unless project.operating_organization_id == membership.organization_id
      return true if effective(membership).allowed?("projects.view_all")
      return true if effective(membership).allowed?("projects.view_assigned") && assigned_any_scope?(membership, project)

      false
    end

    def client_project_visible?(membership, project)
      effective(membership).allowed?("projects.view_org") &&
        project.client_organization_id == membership.organization_id
    end

    def assignment_scope(membership, project)
      return "delivery" if project.coordinator_membership_id == membership.id

      assignment = project.active_assignment_for(membership.user)
      assignment&.access_scope
    end
  end
end
