# frozen_string_literal: true

module Documents
  # P2-OD-042 / F4-05-H1 document access contract (F4-06 Package A).
  module Access
    module_function

    def can_list_project_documents?(membership, project)
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

    # Relation of documents the actor may see metadata for within one project.
    # Does not reveal titles the actor is not entitled to.
    def visible_documents_for_project(membership, project)
      base = Document.where(project_id: project.id).not_archived
      return Document.none unless can_list_project_documents?(membership, project)

      if membership.staff_domain?
        return base if effective(membership).allowed?("projects.view_all")
        return base if delivery_participant?(membership, project)

        scope = assignment_scope(membership, project)
        case scope
        when "review"
          base.where(
            "documents.category IN (?) OR documents.visibility_intent = ?",
            Document::APPROVAL_REQUIRED_CATEGORIES,
            "for_client_release"
          )
        when "collaborator"
          grants = DocumentAccessGrant.active.where(user_id: membership.user_id)
          return base if grants.where(project_id: project.id).exists?

          base.where(id: grants.where.not(document_id: nil).select(:document_id))
        else
          Document.none
        end
      elsif membership.client_domain?
        released_ids = DocumentRelease.active.where(client_organization_id: membership.organization_id).select(:document_id)
        base.where(visibility_intent: "client_submitted").or(base.where(id: released_ids))
      else
        Document.none
      end
    end

    def can_view_metadata?(membership, document)
      return false unless membership&.status == "active" && document.is_a?(Document)
      return false if document.project.simulated? && Rails.env.production?

      project = document.project
      if membership.staff_domain?
        return false unless project.operating_organization_id == membership.organization_id
        return true if effective(membership).allowed?("projects.view_all")
        return false unless assigned_any_scope?(membership, project)

        scope = assignment_scope(membership, project)
        return true if scope == "delivery"
        return review_visible?(document) if scope == "review"
        return grant_visible?(membership, document) if scope == "collaborator"

        false
      elsif membership.client_domain?
        return false unless client_project_visible?(membership, project)
        return true if document.visibility_intent.in?(%w[client_submitted for_client_release])
        return true if document.active_release? && document.active_release.client_organization_id == membership.organization_id

        false
      else
        false
      end
    end

    def can_upload?(membership, project)
      return false unless membership&.status == "active" && project.is_a?(Project)
      return false if project.simulated? && Rails.env.production?
      return false unless upload_catalogue_allowed?(membership)

      if membership.staff_domain?
        return false unless project.operating_organization_id == membership.organization_id
        return true if effective(membership).allowed?("projects.view_all")
        delivery_participant?(membership, project)
      elsif membership.client_domain?
        client_project_visible?(membership, project)
      else
        false
      end
    end

    def can_request_upload?(membership, project)
      return false unless can_upload?(membership, project) || staff_delivery_ops?(membership, project)
      return false unless membership.staff_domain?
      return false unless effective(membership).allowed?("documents.request_upload")

      staff_delivery_ops?(membership, project)
    end

    def can_download_version?(membership, version)
      return false unless membership&.status == "active" && version.is_a?(DocumentVersion)
      return false unless version.downloadable?

      document = version.document
      project = document.project
      return false if project.simulated? && Rails.env.production?
      return false unless can_view_metadata?(membership, document)

      asset = version.storage_asset
      return false if asset.confidential? && !effective(membership).allowed?("documents.access_confidential")

      if membership.staff_domain?
        staff_download_allowed?(membership, document, project)
      elsif membership.client_domain?
        client_download_allowed?(membership, document, version)
      else
        false
      end
    end

    def can_review?(membership, document)
      return false unless membership&.status == "active" && document.is_a?(Document)
      return false unless membership.staff_domain?
      return false unless can_view_metadata?(membership, document)
      return true if effective(membership).allowed?("documents.manage")

      project = document.project
      assignment_scope(membership, project) == "review" &&
        effective(membership).allowed?("reports.review")
    end

    def can_release?(membership, document)
      return false unless membership&.status == "active" && document.is_a?(Document)
      return false unless membership.staff_domain?
      return false unless document.project.operating_organization_id == membership.organization_id

      effective(membership).allowed?("documents.manage") ||
        (delivery_participant?(membership, document.project) && effective(membership).allowed?("reports.release"))
    end

    def can_revoke_release?(membership, release)
      return false unless membership&.status == "active" && release.is_a?(DocumentRelease)
      return false unless release.active?

      can_release?(membership, release.document)
    end

    def delivery_participant?(membership, project)
      Delivery::Access.delivery_participant?(membership, project)
    end

    def assigned_any_scope?(membership, project)
      Delivery::Access.assigned_any_scope?(membership, project)
    end

    def staff_delivery_ops?(membership, project)
      return false unless membership.staff_domain?
      return true if effective(membership).allowed?("projects.manage")
      return true if effective(membership).allowed?("projects.view_all")

      delivery_participant?(membership, project)
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

    def staff_download_allowed?(membership, document, project)
      scope = assignment_scope(membership, project)
      return true if effective(membership).allowed?("projects.view_all")
      return true if scope == "delivery" && delivery_participant?(membership, project)
      return review_visible?(document) if scope == "review"
      return grant_visible?(membership, document) if scope == "collaborator"

      false
    end

    def client_download_allowed?(membership, document, version)
      return false unless document.client_organization_id == membership.organization_id

      if document.visibility_intent == "client_submitted" && document.downloadable?
        return version.uploaded_by_membership&.organization_id == membership.organization_id
      end

      release = document.document_releases.active.find_by(client_organization_id: membership.organization_id)
      release.present? && release.document_version_id == version.id
    end

    def review_visible?(document)
      document.approval_required? || document.visibility_intent == "for_client_release"
    end

    def grant_visible?(membership, document)
      DocumentAccessGrant.active.where(user_id: membership.user_id).any? do |grant|
        grant.grant_scope_document?(document.id) ||
          grant.grant_scope_project?(document.project_id)
      end
    end

    def upload_catalogue_allowed?(membership)
      perms = effective(membership)
      return true if perms.allowed?("documents.upload")

      membership.staff_domain? && perms.allowed?("documents.manage")
    end
  end
end
