# frozen_string_literal: true

module Delivery
  # P2-OD-042: assignment access_scope gates delivery operations.
  # review / collaborator may view when assigned; they do not get projects.manage via assignment alone.
  module Access
    module_function

    def delivery_participant?(membership, project)
      return false unless membership && project.is_a?(Project)
      return true if project.coordinator_membership_id == membership.id

      assignment = project.active_assignment_for(membership.user)
      assignment.present? && assignment.access_scope == "delivery"
    end

    def assigned_any_scope?(membership, project)
      return false unless membership && project.is_a?(Project)
      return true if project.coordinator_membership_id == membership.id

      project.assigned?(membership.user)
    end

    def can_manage_delivery?(membership, project)
      return false unless membership&.status == "active" && membership.staff_domain?

      perms = Authorization::EffectivePermissions.new(membership)
      return true if perms.allowed?("projects.manage")
      return false unless delivery_participant?(membership, project)

      perms.allowed?("assignments.participate") || perms.allowed?("projects.view_assigned")
    end
  end
end
