# frozen_string_literal: true

class UploadRequestPolicy < ApplicationPolicy
  def index?
    project = resolve_project(record)
    return client_list? unless project

    Documents::Access.can_list_project_documents?(membership, project)
  end

  def show?
    project = resolve_project(record)
    return false unless project

    Documents::Access.can_list_project_documents?(membership, project)
  end

  def create?
    project = resolve_project(record)
    return false unless project

    Documents::Access.can_request_upload?(membership, project)
  end

  def submit?
    return false unless record.is_a?(UploadRequest)

    Documents::Access.can_upload?(membership, record.project) && record.open?
  end

  private

    def resolve_project(record)
      case record
      when Project then record
      when UploadRequest then record.project
      else nil
      end
    end

    def client_list?
      membership&.client_domain? && allowed?("projects.view_org")
    end
end
