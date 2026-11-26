# frozen_string_literal: true

module Billing
  module Access
    module_function

    def permissions_for(membership)
      Authorization::EffectivePermissions.new(membership)
    end

    def staff?(membership)
      membership&.status == "active" && membership.staff_domain?
    end

    def client?(membership)
      membership&.status == "active" && membership.client_domain?
    end

    def can_view_metadata?(membership, invoice)
      return false unless membership&.status == "active"
      return false if invoice.simulated? && Rails.env.production?

      perms = permissions_for(membership)
      if staff?(membership)
        return false unless invoice.operating_organization_id == membership.organization_id
        return true if perms.allowed?("billing.view_all")
        return true if perms.allowed?("billing.view") && project_visible?(membership, invoice.project)

        false
      elsif client?(membership)
        return false unless invoice.client_organization_id == membership.organization_id
        return false unless perms.allowed?("billing.view")
        return false unless invoice.issued? && invoice.released_to_client?

        true
      else
        false
      end
    end

    def can_view_amounts?(membership, invoice)
      can_view_metadata?(membership, invoice)
    end

    def can_manage?(membership, invoice = nil)
      return false unless staff?(membership)
      return false unless permissions_for(membership).allowed?("billing.manage")
      return true if invoice.nil?

      invoice.operating_organization_id == membership.organization_id
    end

    def can_issue?(membership, invoice)
      can_manage?(membership, invoice) && invoice&.draft?
    end

    def can_release?(membership, invoice)
      return false unless can_manage?(membership, invoice)
      return false unless invoice.issued?

      true
    end

    def can_record_payment?(membership, invoice)
      return false unless staff?(membership)
      return false unless permissions_for(membership).allowed?("billing.record_payment") ||
                          permissions_for(membership).allowed?("billing.manage")
      return false unless invoice.operating_organization_id == membership.organization_id
      return false unless invoice.issued?

      true
    end

    def can_adjust?(membership, invoice)
      return false unless staff?(membership)
      return false unless permissions_for(membership).allowed?("billing.adjust")
      return false unless invoice.operating_organization_id == membership.organization_id

      true
    end

    def can_download?(membership, invoice)
      return false unless can_view_metadata?(membership, invoice)
      return false if invoice.storage_asset_id.blank?
      return true if staff?(membership)
      return false unless client?(membership)
      return false unless invoice.released_to_client?

      true
    end

    def project_visible?(membership, project)
      return false unless project
      return true if permissions_for(membership).allowed?("projects.view_all")
      return true if permissions_for(membership).allowed?("projects.view_assigned") &&
                     Delivery::Access.assigned_any_scope?(membership, project)

      false
    end
  end
end
